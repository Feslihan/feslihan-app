import http2 from "node:http2";
import crypto from "node:crypto";
import { db } from "./db.js";
import { deviceTokens } from "./schema.js";
import { eq } from "drizzle-orm";

// Minimal APNs client — zero dependencies. ES256 provider JWTs are signed
// with node:crypto (ieee-p1363 gives the raw r||s signature JOSE expects)
// and pushes go over node:http2 (APNs is HTTP/2-only). Volume is tiny
// (friend requests / recipe shares), so one session per send is fine.

const KEY_ID = process.env.APNS_KEY_ID;
const TEAM_ID = process.env.APNS_TEAM_ID;
const TOPIC = process.env.APNS_TOPIC ?? "com.dilarahalavurt.feslihan";

let warnedDisabled = false;

function apnsKey(): crypto.KeyObject | null {
  const b64 = process.env.APNS_KEY_BASE64;
  if (!b64 || !KEY_ID || !TEAM_ID) return null;
  return crypto.createPrivateKey(Buffer.from(b64, "base64").toString("utf8"));
}

function b64url(data: Buffer | string): string {
  return Buffer.from(data).toString("base64url");
}

// APNs accepts provider tokens 20–60 minutes old; cache and refresh at 50.
let cachedJwt: { token: string; issuedAt: number } | null = null;

function getApnsJwt(): string | null {
  const now = Math.floor(Date.now() / 1000);
  if (cachedJwt && now - cachedJwt.issuedAt < 50 * 60) return cachedJwt.token;

  const key = apnsKey();
  if (!key) return null;

  const header = b64url(JSON.stringify({ alg: "ES256", kid: KEY_ID }));
  const claims = b64url(JSON.stringify({ iss: TEAM_ID, iat: now }));
  const signature = crypto
    .sign("sha256", Buffer.from(`${header}.${claims}`), {
      key,
      dsaEncoding: "ieee-p1363",
    })
    .toString("base64url");

  const token = `${header}.${claims}.${signature}`;
  cachedJwt = { token, issuedAt: now };
  return token;
}

export interface PushPayload {
  title: string;
  body: string;
  /** Custom keys delivered alongside aps (e.g. { type: "share" }). */
  data?: Record<string, string>;
}

interface ApnsResult {
  status: number;
  reason?: string;
}

/** Send one alert push. Resolves with the APNs status; never throws. */
export function sendPush(
  token: string,
  environment: string,
  payload: PushPayload
): Promise<ApnsResult> {
  const jwt = getApnsJwt();
  if (!jwt) {
    if (!warnedDisabled) {
      console.warn("[apns] APNS_* env vars missing — pushes disabled");
      warnedDisabled = true;
    }
    return Promise.resolve({ status: 0, reason: "disabled" });
  }

  const host =
    environment === "sandbox"
      ? "https://api.sandbox.push.apple.com"
      : "https://api.push.apple.com";

  const body = JSON.stringify({
    aps: {
      alert: { title: payload.title, body: payload.body },
      sound: "default",
    },
    ...(payload.data ?? {}),
  });

  return new Promise((resolve) => {
    const session = http2.connect(host);
    const finish = (result: ApnsResult) => {
      session.close();
      resolve(result);
    };

    session.on("error", (err) => finish({ status: -1, reason: String(err) }));

    const req = session.request({
      ":method": "POST",
      ":path": `/3/device/${token}`,
      authorization: `bearer ${jwt}`,
      "apns-topic": TOPIC,
      "apns-push-type": "alert",
      "apns-priority": "10",
      "content-type": "application/json",
    });

    let status = 0;
    let responseBody = "";
    req.setEncoding("utf8");
    req.on("response", (headers) => {
      status = Number(headers[":status"] ?? 0);
    });
    req.on("data", (chunk) => (responseBody += chunk));
    req.on("end", () => {
      let reason: string | undefined;
      try {
        reason = JSON.parse(responseBody).reason;
      } catch {
        // empty body on 200
      }
      finish({ status, reason });
    });
    req.on("error", (err) => finish({ status: -1, reason: String(err) }));
    req.end(body);
  });
}

/**
 * Push to every registered device of a user. Dead tokens (uninstalled app,
 * environment mismatch) are pruned. Never throws — a push failure must never
 * fail the API request that triggered it.
 */
export async function sendPushToUser(
  userId: string,
  payload: PushPayload
): Promise<void> {
  try {
    const tokens = await db
      .select()
      .from(deviceTokens)
      .where(eq(deviceTokens.userId, userId));

    for (const device of tokens) {
      const result = await sendPush(device.token, device.environment, payload);
      if (
        result.status === 410 ||
        (result.status === 400 && result.reason === "BadDeviceToken")
      ) {
        await db.delete(deviceTokens).where(eq(deviceTokens.token, device.token));
        console.log(`[apns] pruned dead token for ${userId} (${result.reason ?? result.status})`);
      } else if (result.status !== 200 && result.status !== 0) {
        console.warn(`[apns] push to ${userId} failed: ${result.status} ${result.reason ?? ""}`);
      }
    }
  } catch (err) {
    console.error("[apns] sendPushToUser error:", err);
  }
}
