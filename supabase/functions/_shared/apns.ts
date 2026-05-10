/**
 * APNs HTTP/2 + JWT auth helper.
 * Signs a JWT with the p8 key and sends push notifications via APNs REST API.
 *
 * Required env vars:
 *   APNS_KEY_P8       — PEM content of the .p8 file (include BEGIN/END PRIVATE KEY lines)
 *   APNS_KEY_ID       — 10-char key ID from Apple Developer portal
 *   APNS_TEAM_ID      — 10-char team ID from Apple Developer portal
 *   APNS_BUNDLE_ID    — app bundle ID (e.g. "DariusEhsani.Apollo")
 */

const APNS_HOST = "https://api.push.apple.com";

// JWT is valid for 1 hour per Apple docs; cache it to avoid signing on every request.
let cachedJwt: { token: string; expiresAt: number } | null = null;

async function getApnsJwt(): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cachedJwt && cachedJwt.expiresAt > now + 60) {
    return cachedJwt.token;
  }

  const keyP8 = Deno.env.get("APNS_KEY_P8") ?? "";
  const keyId = Deno.env.get("APNS_KEY_ID") ?? "";
  const teamId = Deno.env.get("APNS_TEAM_ID") ?? "";

  // Strip PEM headers and decode base64.
  const pem = keyP8
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\s+/g, "");
  const der = Uint8Array.from(atob(pem), (c) => c.charCodeAt(0));

  const key = await crypto.subtle.importKey(
    "pkcs8",
    der,
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"]
  );

  const header = { alg: "ES256", kid: keyId };
  const payload = { iss: teamId, iat: now };

  const encode = (obj: unknown) =>
    btoa(JSON.stringify(obj))
      .replace(/=/g, "")
      .replace(/\+/g, "-")
      .replace(/\//g, "_");

  const message = `${encode(header)}.${encode(payload)}`;
  const msgBytes = new TextEncoder().encode(message);
  const sigBytes = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" },
    key,
    msgBytes
  );
  const sig = btoa(String.fromCharCode(...new Uint8Array(sigBytes)))
    .replace(/=/g, "")
    .replace(/\+/g, "-")
    .replace(/\//g, "_");

  const token = `${message}.${sig}`;
  cachedJwt = { token, expiresAt: now + 3600 };
  return token;
}

export interface ApnsPayload {
  alert: { title: string; body: string };
  badge?: number;
  sound?: string;
  /** Custom data forwarded to the app (deep link etc.) */
  data?: Record<string, string>;
  collapseId?: string;
  /** APNs interruption-level (passive suppresses Focus/quiet hours) */
  interruptionLevel?: "passive" | "active" | "time-sensitive" | "critical";
}

export interface SendResult {
  token: string;
  success: boolean;
  /** true if the token is permanently invalid (device unregistered) */
  unregistered: boolean;
}

/**
 * Sends a push notification to a single device token.
 * Returns whether it succeeded and whether the token should be disabled.
 */
export async function sendApnsPush(
  deviceToken: string,
  payload: ApnsPayload,
  sandbox = false
): Promise<SendResult> {
  const bundleId = Deno.env.get("APNS_BUNDLE_ID") ?? "";
  const host = sandbox
    ? "https://api.sandbox.push.apple.com"
    : APNS_HOST;

  const jwt = await getApnsJwt();

  const apsBody: Record<string, unknown> = {
    alert: payload.alert,
    sound: payload.sound ?? "default",
  };
  if (payload.badge !== undefined) apsBody.badge = payload.badge;
  if (payload.interruptionLevel) {
    apsBody["interruption-level"] = payload.interruptionLevel;
  }

  const body: Record<string, unknown> = { aps: apsBody };
  if (payload.data) {
    for (const [k, v] of Object.entries(payload.data)) {
      body[k] = v;
    }
  }

  const headers: Record<string, string> = {
    "authorization": `bearer ${jwt}`,
    "apns-push-type": "alert",
    "apns-topic": bundleId,
    "content-type": "application/json",
  };
  if (payload.collapseId) headers["apns-collapse-id"] = payload.collapseId;

  try {
    const res = await fetch(`${host}/3/device/${deviceToken}`, {
      method: "POST",
      headers,
      body: JSON.stringify(body),
    });

    if (res.status === 200) {
      return { token: deviceToken, success: true, unregistered: false };
    }

    const json = await res.json().catch(() => ({}));
    const reason = (json as { reason?: string }).reason ?? "";
    const unregistered = res.status === 410 || reason === "Unregistered";
    return { token: deviceToken, success: false, unregistered };
  } catch {
    return { token: deviceToken, success: false, unregistered: false };
  }
}
