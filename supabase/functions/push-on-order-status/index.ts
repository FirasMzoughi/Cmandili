/**
 * push-on-order-status
 *
 * Supabase Edge Function — fans out FCM pushes for order lifecycle events.
 *
 * Two invocation modes:
 *
 *   1. Status change (default) — from the notify_fcm_on_order_status trigger.
 *      Body: { order_id, status }
 *      Routes the notification to:
 *        - the customer (orders.user_id)
 *        - the partner (owner of orders.restaurant_id / supermarket_id
 *          looked up via partners.entity_id)
 *        - the assigned driver, if any (orders.driver_id -> drivers.user_id)
 *
 *   2. Driver fan-out — from the notify_fcm_fanout_ready_order trigger.
 *      Body: { event: 'driver_fanout', order_id, status: 'ready' }
 *      Looks up the pickup lat/lng (from restaurants or supermarkets) and
 *      calls the `nearby_online_drivers` RPC to find online drivers within
 *      a radius, then pushes to each of them.
 *
 * Required environment variables (set with `supabase secrets set`):
 *   SUPABASE_URL               — automatically provided by Supabase
 *   SERVICE_ROLE_KEY           — service role JWT (bypasses RLS).
 *                                Cannot be named SUPABASE_*; that prefix is
 *                                reserved by Supabase.
 *   FCM_SERVICE_ACCOUNT_JSON   — Firebase service account JSON, base64-encoded
 *   TRIGGER_SHARED_SECRET      — random string only the DB triggers know.
 *                                REQUIRED. `verify_jwt = true` (config.toml)
 *                                is not real access control here: the DB
 *                                triggers historically authenticated with the
 *                                public anon/publishable key (see
 *                                20260425_inline_edge_function_url.sql), which
 *                                is compiled into every shipped Flutter app —
 *                                so any caller with that key could POST here
 *                                directly and spam arbitrary users with pushes
 *                                (driver "10s to accept" alarms, fake status
 *                                updates, etc). This secret is checked
 *                                independently of the anon-key JWT check.
 *                                Generate one with `openssl rand -hex 32`,
 *                                then:
 *                                  supabase secrets set TRIGGER_SHARED_SECRET=<value>
 *                                  ALTER DATABASE postgres SET app.edge_function_secret = '<value>';
 *   DRIVER_FANOUT_RADIUS_KM    — optional, default 7
 *
 * Invoke URL: POST /functions/v1/push-on-order-status
 */

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient, SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2';

// ── helpers ──────────────────────────────────────────────────────────────────

const CUSTOMER_COPY: Record<string, { title: string; body: string }> = {
  confirmed: { title: '✅ Order Confirmed', body: 'Order confirmed — we\'re preparing your food!' },
  preparing: { title: '👨‍🍳 Preparing', body: 'Your order is being prepared.' },
  ready:     { title: '📦 Ready for Pickup', body: 'Your order is ready and waiting for a driver.' },
  pickedUp:  { title: '🛵 Driver Picked Up', body: 'A driver has picked up your order.' },
  onTheWay:  { title: '🚀 On the Way', body: 'Your order is on the way!' },
  delivered: { title: '🎉 Delivered!', body: 'Your order has been delivered. Enjoy!' },
  cancelled: { title: '❌ Cancelled', body: 'Your order has been cancelled.' },
};

const PARTNER_COPY: Record<string, { title: string; body: string }> = {
  pending:   { title: '🔔 New Order', body: 'A new order is waiting for confirmation.' },
  confirmed: { title: '✅ Order Confirmed', body: 'You confirmed a new order.' },
  ready:     { title: '📦 Order Ready', body: 'Order marked ready — driver notified.' },
  pickedUp:  { title: '🛵 Picked Up', body: 'A driver picked up the order.' },
  delivered: { title: '🎉 Delivered', body: 'Order delivered.' },
  cancelled: { title: '❌ Cancelled', body: 'Order cancelled.' },
};

const DRIVER_COPY: Record<string, { title: string; body: string }> = {
  pickedUp:  { title: '🛵 Pickup Confirmed', body: 'Pickup confirmed — drive safe!' },
  onTheWay:  { title: '🚗 On the Way', body: 'Heading to the customer.' },
  delivered: { title: '✅ Delivered', body: 'Delivery complete. Payment collected if cash.' },
  cancelled: { title: '❌ Order Cancelled', body: 'This order was cancelled.' },
};

function copyFor(role: 'customer' | 'partner' | 'driver', status: string) {
  const src = role === 'customer' ? CUSTOMER_COPY
            : role === 'partner'  ? PARTNER_COPY
            : DRIVER_COPY;
  return src[status] ?? { title: 'Order Update', body: `Status: ${status}` };
}

// Firebase OAuth — sign JWT with RSA key from service account JSON.
async function getAccessToken(serviceAccountJson: string): Promise<string> {
  const sa = JSON.parse(serviceAccountJson);
  const now = Math.floor(Date.now() / 1000);

  const header  = btoa(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const payload = btoa(JSON.stringify({
    iss: sa.client_email,
    sub: sa.client_email,
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
  }));

  const unsigned = `${header}.${payload}`;
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
    new TextEncoder().encode(unsigned),
  );

  const jwt = `${unsigned}.${btoa(String.fromCharCode(...new Uint8Array(signature)))}`;

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

async function sendFcm(
  accessToken: string,
  projectId: string,
  token: string,
  title: string,
  body: string,
  data: Record<string, string>,
) {
  const url = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`;

  // Alarm-grade events (delivery offers, parcel broadcasts) MUST be data-only.
  // If an FCM message carries a `notification` block, the Android FCM SDK
  // renders it itself while the app is backgrounded/killed and never calls
  // CmandiliMessagingService.onMessageReceived() — so the custom alarm channel
  // (sound + FLAG_INSISTENT + fullScreenIntent) is bypassed entirely and the
  // notification lands silently on the manifest default channel instead.
  // Data-only keeps onMessageReceived() in charge in every app state.
  // driver_fanout is the event the DB triggers actually fire for a new
  // ready order (see migrations 20260424/20260425/20260512), so it needs the
  // same alarm treatment as the other two — it was previously silent.
  // The partner app gates its alarm on data.type === 'new_order' (not event),
  // so that carries the same alarm-grade treatment.
  const isAlarm =
    data.event === 'offer_to_driver' ||
    data.event === 'parcel_broadcast' ||
    data.event === 'driver_fanout' ||
    data.type === 'new_order';

  // The native/Dart handlers read title+body out of the data bag, so they have
  // to travel there once the `notification` block is gone.
  const payload = isAlarm ? { ...data, title, body } : data;

  const message: Record<string, unknown> = {
    token,
    data: payload,
    android: {
      priority: 'high',
      ...(isAlarm ? {} : { notification: { channel_id: 'cmandili_orders' } }),
    },
    apns: {
      headers: { 'apns-priority': '10' },
      // Data-only on Android still needs an APNs alert for iOS to surface it,
      // plus content-available so the app is woken to play the alarm sound.
      payload: {
        aps: isAlarm
          ? { alert: { title, body }, sound: 'new_order.wav', 'content-available': 1 }
          : { alert: { title, body } },
      },
    },
  };
  if (!isAlarm) message.notification = { title, body };

  await fetch(url, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${accessToken}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ message }),
  });
}

async function tokensForUser(supabase: SupabaseClient, userId: string): Promise<string[]> {
  const { data } = await supabase
    .from('device_tokens')
    .select('token')
    .eq('user_id', userId);
  return (data ?? []).map((r: { token: string }) => r.token);
}

async function pushToUsers(
  supabase: SupabaseClient,
  accessToken: string,
  projectId: string,
  userIds: string[],
  title: string,
  body: string,
  data: Record<string, string>,
): Promise<number> {
  const all = await Promise.all(userIds.map(id => tokensForUser(supabase, id)));
  const tokens = Array.from(new Set(all.flat()));
  if (tokens.length === 0) return 0;
  await Promise.allSettled(
    tokens.map(t => sendFcm(accessToken, projectId, t, title, body, data)),
  );
  return tokens.length;
}

// ── handler ──────────────────────────────────────────────────────────────────

serve(async (req: Request) => {
  if (req.method !== 'POST') {
    return new Response('Method Not Allowed', { status: 405 });
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
  // SERVICE_ROLE_KEY (NOT SUPABASE_SERVICE_KEY): Supabase reserves the
  // SUPABASE_* prefix and rejects setting secrets with that prefix.
  const serviceKey  = Deno.env.get('SERVICE_ROLE_KEY')!;
  const saJsonB64   = Deno.env.get('FCM_SERVICE_ACCOUNT_JSON')!;
  const sharedSecret = Deno.env.get('TRIGGER_SHARED_SECRET');
  const fanoutRadius = Number(Deno.env.get('DRIVER_FANOUT_RADIUS_KM') ?? '7');

  if (!supabaseUrl || !serviceKey || !saJsonB64) {
    return new Response('Missing env vars', { status: 500 });
  }

  // `verify_jwt = true` (config.toml) only proves the caller has *some*
  // valid Supabase JWT — the public anon/publishable key qualifies, and
  // that key is compiled into every shipped Flutter app. Without this
  // check, anyone holding the anon key could POST here directly and spam
  // arbitrary users with pushes (fake status updates, repeated driver
  // "10s to accept" alarms, etc). Fail closed if the secret isn't
  // configured — better to silently not push than to be an open relay.
  const authHeader = req.headers.get('Authorization') ?? '';
  const presented = authHeader.startsWith('Bearer ') ? authHeader.slice(7) : '';
  if (!sharedSecret || presented !== sharedSecret) {
    return new Response('Unauthorized', { status: 401 });
  }

  const { event, order_id, status } = await req.json();
  if (!order_id || !status) {
    return new Response('Missing order_id or status', { status: 400 });
  }

  const supabase = createClient(supabaseUrl, serviceKey);
  const saJson   = atob(saJsonB64);
  const sa       = JSON.parse(saJson);
  const projectId = sa.project_id as string;
  const accessToken = await getAccessToken(saJson);

  const data = { order_id, status, event: event ?? 'status' };

  // ── Mode C: offer an order to a single driver (10s window) ─────────────────
  // Triggered by the offer_order_to_driver RPC. The order's
  // assigned_driver_id has already been updated; we just need to push.
  if (event === 'offer_to_driver') {
    const { driver_id } = await (async () => {
      // The body was already parsed at the top of serve(); re-read driver_id
      // from there. We can't reuse the destructured `event/order_id/status`
      // bag because driver_id wasn't pulled out — so look it up via DB.
      const { data: row } = await supabase
        .from('orders')
        .select('assigned_driver_id')
        .eq('id', order_id)
        .maybeSingle();
      return { driver_id: row?.assigned_driver_id as string | null };
    })();

    if (!driver_id) {
      return new Response('No assigned driver', { status: 200 });
    }

    const { data: drow } = await supabase
      .from('drivers')
      .select('user_id')
      .eq('id', driver_id)
      .maybeSingle();
    const driverUserId = drow?.user_id as string | undefined;
    if (!driverUserId) {
      return new Response('Driver has no auth user', { status: 200 });
    }

    const sent = await pushToUsers(
      supabase, accessToken, projectId, [driverUserId],
      '🔔 New delivery — 10s to accept',
      'Tap to view the order. Auto-passes if you don\'t answer.',
      { ...data, urgent: '1' },
    );
    return new Response(JSON.stringify({ mode: 'offer', sent }), {
      headers: { 'Content-Type': 'application/json' },
    });
  }

  // ── Mode B: fan out to nearby online drivers (legacy / fallback) ───────────
  if (event === 'driver_fanout') {
    // Look up the order to get pickup coords via its restaurant/supermarket.
    const { data: order } = await supabase
      .from('orders')
      .select('restaurant_id, supermarket_id, pickup_address')
      .eq('id', order_id)
      .maybeSingle();

    if (!order) return new Response('Order not found', { status: 404 });

    let lat: number | null = null;
    let lng: number | null = null;

    if (order.restaurant_id) {
      const { data: r } = await supabase
        .from('restaurants')
        .select('latitude, longitude')
        .eq('id', order.restaurant_id)
        .maybeSingle();
      lat = r?.latitude ?? null;
      lng = r?.longitude ?? null;
    } else if (order.supermarket_id) {
      const { data: s } = await supabase
        .from('supermarkets')
        .select('latitude, longitude')
        .eq('id', order.supermarket_id)
        .maybeSingle();
      lat = s?.latitude ?? null;
      lng = s?.longitude ?? null;
    } else if (order.pickup_address) {
      // Courier orders: pickup_address is JSONB with {lat, lng}
      const p = order.pickup_address as { lat?: number; lng?: number };
      lat = p?.lat ?? null;
      lng = p?.lng ?? null;
    }

    if (lat === null || lng === null || (lat === 0 && lng === 0)) {
      return new Response('No pickup coords on order', { status: 200 });
    }

    const { data: drivers } = await supabase.rpc('nearby_online_drivers', {
      p_lat: lat,
      p_lng: lng,
      p_radius_km: fanoutRadius,
    });

    if (!drivers || drivers.length === 0) {
      return new Response('No nearby drivers', { status: 200 });
    }

    const userIds = (drivers as { user_id: string }[]).map(d => d.user_id);
    const sent = await pushToUsers(
      supabase, accessToken, projectId, userIds,
      '🔔 New delivery nearby',
      'A new order is ready for pickup near you.',
      data,
    );
    return new Response(JSON.stringify({ mode: 'fanout', sent }), {
      headers: { 'Content-Type': 'application/json' },
    });
  }

  // ── Mode A: status change → customer + partner + assigned driver ───────────

  const { data: order } = await supabase
    .from('orders')
    .select('user_id, restaurant_id, supermarket_id, driver_id')
    .eq('id', order_id)
    .maybeSingle();

  if (!order) return new Response('Order not found', { status: 404 });

  // Resolve partner user_id via partners table (partner_type + entity_id)
  let partnerUserId: string | null = null;
  if (order.restaurant_id) {
    const { data: p } = await supabase
      .from('partners')
      .select('user_id')
      .eq('partner_type', 'restaurant')
      .eq('entity_id', order.restaurant_id)
      .maybeSingle();
    partnerUserId = p?.user_id ?? null;
  } else if (order.supermarket_id) {
    const { data: p } = await supabase
      .from('partners')
      .select('user_id')
      .eq('partner_type', 'supermarket')
      .eq('entity_id', order.supermarket_id)
      .maybeSingle();
    partnerUserId = p?.user_id ?? null;
  }

  // Resolve assigned driver user_id
  let driverUserId: string | null = null;
  if (order.driver_id) {
    const { data: d } = await supabase
      .from('drivers')
      .select('user_id')
      .eq('id', order.driver_id)
      .maybeSingle();
    driverUserId = d?.user_id ?? null;
  }

  const results: Record<string, number> = {};

  if (order.user_id) {
    const c = copyFor('customer', status);
    results.customer = await pushToUsers(
      supabase, accessToken, projectId, [order.user_id], c.title, c.body, data,
    );
  }
  if (partnerUserId) {
    const c = copyFor('partner', status);
    // The partner app's native alarm service and Dart handler both gate on
    // data.type === 'new_order' — nothing was ever sending that key, so the
    // partner's loud new-order alarm could never fire. A freshly inserted
    // order arrives here as status 'pending' (the INSERT trigger posts no
    // event), which is exactly the case that should ring.
    const partnerData = status === 'pending'
      ? { ...data, type: 'new_order' }
      : data;
    results.partner = await pushToUsers(
      supabase, accessToken, projectId, [partnerUserId], c.title, c.body, partnerData,
    );
  }
  if (driverUserId) {
    const c = copyFor('driver', status);
    results.driver = await pushToUsers(
      supabase, accessToken, projectId, [driverUserId], c.title, c.body, data,
    );
  }

  return new Response(JSON.stringify({ mode: 'status', ...results }), {
    headers: { 'Content-Type': 'application/json' },
  });
});
