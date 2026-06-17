import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.3";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");
    let geminiApiKey = Deno.env.get("GEMINI_API_KEY")?.trim() || "";
    // Aggressively remove any surrounding quotes that might have been accidentally saved in Supabase Secrets
    geminiApiKey = geminiApiKey.replace(/^["']+|["']+$/g, '');

    if (!supabaseUrl || !supabaseAnonKey || !geminiApiKey) {
      throw new Error("Missing environment variables.");
    }

    // Initialize Supabase client with the Auth context of the user making the request
    const authHeader = req.headers.get("Authorization");
    const supabase = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader || "" } },
    });

    // Parse request payload
    const { base64Image, partnerId, partnerType } = await req.json();

    if (!base64Image || !partnerId || !partnerType) {
      throw new Error("Missing required payload fields: base64Image, partnerId, partnerType");
    }

    // ─── Detect MIME type dynamically from base64 prefix ────────────────────────
    // Flutter's image_picker can return JPEG, PNG or WEBP depending on the source.
    // Sending the wrong mimeType is the #1 cause of Gemini 400 errors.
    let cleanBase64 = base64Image;
    let detectedMimeType = "image/jpeg"; // safe default

    const prefixMatch = base64Image.match(/^data:(image\/\w+);base64,/);
    if (prefixMatch) {
      detectedMimeType = prefixMatch[1]; // e.g. "image/png", "image/webp"
      cleanBase64 = base64Image.replace(/^data:image\/\w+;base64,/, "");
    } else {
      // No prefix – inspect the raw bytes via magic numbers
      try {
        const header = atob(cleanBase64.substring(0, 16));
        if (header.startsWith("\x89PNG")) detectedMimeType = "image/png";
        else if (header.startsWith("RIFF")) detectedMimeType = "image/webp";
      } catch (_) { /* keep image/jpeg if decoding fails */ }
    }

    console.log(`Detected mimeType: ${detectedMimeType}, base64 length: ${cleanBase64.length}`);

    // Call Gemini API (1.5 Flash is ideal for fast vision tasks)
    const geminiUrl = `https://generativelanguage.googleapis.com/v1/models/gemini-1.5-flash:generateContent?key=${encodeURIComponent(geminiApiKey)}`;
    
    const prompt = `Tu es un assistant spécialisé dans l'extraction de données pour un catalogue de livraison en Tunisie. Analyse l'image de ce menu. Extrais chaque article, son prix (en Dinar Tunisien, convertis les formats comme '12 DT' en nombre décimal), et déduis sa catégorie logique. Tu dois renvoyer UNIQUEMENT un objet JSON valide avec cette structure exacte : { "items": [ { "name": "Nom", "price": 12.5, "category": "Catégorie", "description": "Ingrédients ou courte description si présente" } ] }. You are a professional menu extractor. Return ONLY a raw JSON object. Do not include markdown formatting, code blocks (like \`\`\`json), or any introductory/explanatory text. Your response must start with { and end with }.`;

    const geminiPayload = {
      contents: [
        {
          parts: [
            { text: prompt },
            {
              inlineData: {
                mimeType: detectedMimeType,
                data: cleanBase64,
              },
            },
          ],
        },
      ],
      generationConfig: {
        temperature: 0.1,
        maxOutputTokens: 8192,
        // NOTE: responseMimeType is intentionally omitted here.
        // Setting it to "application/json" while also sending an image
        // causes a 400 INVALID_ARGUMENT on some Gemini 1.5 Flash builds.
        // We parse the JSON from the text response ourselves instead.
      }
    };

    const geminiRes = await fetch(geminiUrl, {
      method: "POST",
      headers: { 
        "Content-Type": "application/json"
      },
      body: JSON.stringify(geminiPayload),
    });

    if (!geminiRes.ok) {
      const errorBody = await geminiRes.text();
      console.error(`Gemini API Error (HTTP ${geminiRes.status}):`, errorBody);
      // Surface a clear, readable message to the Flutter client
      let reason = errorBody;
      try {
        const parsed = JSON.parse(errorBody);
        reason = parsed?.error?.message ?? errorBody;
      } catch (_) { /* keep raw text */ }
      throw new Error(`Failed to process image with Gemini (${geminiRes.status}): ${reason}`);
    }

    const geminiData = await geminiRes.json();
    
    // Gemini can return content in two paths depending on finish reason
    let extractedText: string | undefined =
      geminiData.candidates?.[0]?.content?.parts?.[0]?.text ??
      geminiData.candidates?.[0]?.parts?.[0]?.text;

    if (!extractedText) {
      const finishReason = geminiData.candidates?.[0]?.finishReason ?? "UNKNOWN";
      console.error("Gemini returned no text. Full response:", JSON.stringify(geminiData));
      throw new Error(`Gemini returned no text content (finishReason: ${finishReason}). The image may be unreadable or blocked by safety filters.`);
    }

    console.log('Raw Gemini Response (first 500 chars):', extractedText.substring(0, 500));

    // Clean the response: remove markdown code block backticks if Gemini ignored instructions
    extractedText = extractedText.replace(/```json/gi, '').replace(/```/g, '').trim();

    // Some responses have extra text before the JSON object — extract just the JSON part
    const jsonStart = extractedText.indexOf('{');
    const jsonEnd = extractedText.lastIndexOf('}');
    if (jsonStart !== -1 && jsonEnd !== -1 && jsonEnd > jsonStart) {
      extractedText = extractedText.substring(jsonStart, jsonEnd + 1);
    }

    // Parse the JSON response
    let parsedData: any;
    try {
      parsedData = JSON.parse(extractedText);
    } catch (parseErr) {
      console.error("JSON parse failed. Raw text:", extractedText);
      throw new Error(`Gemini response was not valid JSON. Raw output: ${extractedText.substring(0, 200)}`);
    }
    const items = parsedData.items || [];

    if (items.length === 0) {
      return new Response(
        JSON.stringify({ message: "No items found in the image", count: 0 }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 200 }
      );
    }

    // Prepare data for Supabase bulk insert
    const isRestaurant = partnerType === "restaurant";
    const tableName = isRestaurant ? "food_items" : "grocery_items";
    const foreignKey = isRestaurant ? "restaurant_id" : "supermarket_id";

    const rowsToInsert = items.map((item: any) => {
      const baseObj = {
        [foreignKey]: partnerId,
        name: item.name,
        price: Number(item.price) || 0,
        category: item.category || "General",
        description: item.description || "",
        is_available: true,
      };

      if (!isRestaurant) {
        // grocery items have specific fields (e.g. unit) in cmandili
        return {
          ...baseObj,
          unit: "1 pc", // default unit
          is_organic: false
        };
      } else {
        return {
          ...baseObj,
          is_vegetarian: false,
          is_spicy: false,
          preparation_time: 15 // default prep time
        };
      }
    });

    const { data, error } = await supabase.from(tableName).insert(rowsToInsert).select();

    if (error) {
      console.error("Supabase insert error:", error);
      throw new Error(`Database insert failed: ${error.message}`);
    }

    return new Response(
      JSON.stringify({ message: "Success", count: data.length, inserted: data }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 200 }
    );

  } catch (err: any) {
    console.error("Function error:", err.message);
    return new Response(JSON.stringify({ error: err.message }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 400,
    });
  }
});
