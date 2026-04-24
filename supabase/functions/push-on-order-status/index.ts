/**
 * push-on-order-status
 *
 * Supabase Edge Function — triggered by the `on_order_status_changed` DB trigger
 * via a pg_net HTTP call, OR called directly from the Flutter app after a status
 * update. Sends an FCM v1 push notification to every device token registered for
 * the order's customer.
 *
 * Required environment variables (set in Supabase Dashboard → Settings → Edge Functions):
 *   SUPABASE_URL            — your project URL
 *   SUPABASE_SERVICE_KEY    — service role key (bypasses RLS)
 *   FCM_SERVICE_ACCOUNT_JSON — full Firebase service account JSON (base64-encoded)
 *
 * Invoke URL: POST /functions/v1/push-on-order-status
 * Body: { "order_id": "<uuid>", "status": "<new_status>" }
 */

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

// ── helpers ──────────────────────────────────────────────────────────────────

function statusToHuman(status: string): string {
  const map: Record<string, string> = {
    confirmed:  'Order confirmed — we\'re preparing your food!',
    preparing:  'Your order is being prepared.',
    ready:      'Your order is ready for pickup.',
    pickedUp:   'A driver has picked up your order.',
    onTheWay:   'Your order is on the way!',
    delivered:  'Your order has been delivered. Enjoy!',
    cancelled:  'Your order has been cancelled.',
  };
  return map[status] ?? `Order status updated to: ${status}`;
}

function statusToTitle(status: string): string {
  const map: Record<string, string> = {
    confirmed:  '✅ Order Confirmed',
    preparing:  '👨‍🍳 Preparing Your Order',
    ready:      '📦 Order Ready',
    pickedUp:   '🛵 Driver Picked Up',
    onTheWay:   '🚀 On the Way',
    delivered:  '🎉 Delivered!',
    cancelled:  '❌ Order Cancelled',
  };
  return map[status] ?? 'Order Update';
}

async function getAccessToken(serviceAccountJson: string): Promise<string> {
  const sa = JSON.parse(serviceAccountJson);
  const now = Math.floor(Date.now() / 1000);

  const header = btoa(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const payload = btoa(JSON.stringify({
    iss: sa.client_email,
    sub: sa.client_email,
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
  }));

  const unsignedToken = `${header}.${payload}`;

  // Import the RSA private key
  const pemKey = sa.private_key
    .replace('-----BEGIN PRIVATE KEY-----', '')
    .replace('-----END PRIVATE KEY-----', '')
    .replace(/\n/g, '');

  const binaryKey = Uint8Array.from(atob(pemKey), c => c.charCodeAt(0));
  const cryptoKey = await crypto.subtle.importKey(
    'pkcs8',
    binaryKey,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );

  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    cryptoKey,
    new TextEncoder().encode(unsignedToken),
  );

  const jwt = `${unsignedToken}.${btoa(String.fromCharCode(...new Uint8Array(signature)))}`;

  const tokenResp = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }),
  });

  const tokenData = await tokenResp.json();
  return tokenData.access_token as string;
}

async function sendFcmNotification(
  accessToken: string,
  projectId: string,
  token: string,
  title: string,
  body: string,
  data: Record<string, string>,
): Promise<void> {
  const url = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`;
  await fetch(url, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${accessToken}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      message: {
        token,
        notification: { title, body },
        data,
        android: { priority: 'high' },
        apns: { headers: { 'apns-priority': '10' } },
      },
    }),
  });
}

// ── handler ──────────────────────────────────────────────────────────────────

serve(async (req: Request) => {
  if (req.method !== 'POST') {
    return new Response('Method Not Allowed', { status: 405 });
  }

  const supabaseUrl    = Deno.env.get('SUPABASE_URL')!;
  const serviceKey     = Deno.env.get('SUPABASE_SERVICE_KEY')!;
  const saJsonB64      = Deno.env.get('FCM_SERVICE_ACCOUNT_JSON')!;

  if (!supabaseUrl || !serviceKey || !saJsonB64) {
    return new Response('Missing env vars', { status: 500 });
  }

  const { order_id, status } = await req.json();
  if (!order_id || !status) {
    return new Response('Missing order_id or status', { status: 400 });
  }

  const supabase = createClient(supabaseUrl, serviceKey);

  // Get order's customer user_id
  const { data: order, error: orderErr } = await supabase
    .from('orders')
    .select('user_id')
    .eq('id', order_id)
    .single();

  if (orderErr || !order) {
    return new Response(`Order not found: ${orderErr?.message}`, { status: 404 });
  }

  // Get all device tokens for this user
  const { data: tokens } = await supabase
    .from('device_tokens')
    .select('token')
    .eq('user_id', order.user_id);

  if (!tokens || tokens.length === 0) {
    return new Response('No device tokens', { status: 200 });
  }

  const saJson     = atob(saJsonB64);
  const sa         = JSON.parse(saJson);
  const projectId  = sa.project_id as string;
  const accessToken = await getAccessToken(saJson);

  const title = statusToTitle(status);
  const body  = statusToHuman(status);
  const data  = { order_id, status };

  await Promise.allSettled(
    tokens.map(({ token }: { token: string }) =>
      sendFcmNotification(accessToken, projectId, token, title, body, data),
    ),
  );

  return new Response(JSON.stringify({ sent: tokens.length }), {
    headers: { 'Content-Type': 'application/json' },
  });
});
