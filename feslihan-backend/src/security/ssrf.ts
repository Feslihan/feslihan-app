import { lookup } from "node:dns/promises";
import net from "node:net";

/**
 * SSRF protection for server-side URL fetching.
 *
 * The old scraper guard was `url.includes("nefisyemektarifleri.com")`, a bare
 * substring match. A URL like
 *   http://169.254.169.254/latest/meta-data/#nefisyemektarifleri.com
 * passed that check and was fetched server-side, exposing cloud metadata.
 *
 * This module validates that a URL points at an allowlisted public host, that
 * neither the literal host nor its resolved addresses fall in a private /
 * link-local / loopback range, and follows redirects with the same checks
 * applied to every hop.
 */

// Hosts the recipe scraper is allowed to reach. Exact-match only (plus the
// bare apex for a `www.` entry) — no substring or suffix matching.
const ALLOWED_HOSTS = new Set([
  "nefisyemektarifleri.com",
  "www.nefisyemektarifleri.com",
]);

const MAX_REDIRECTS = 3;
const DEFAULT_TIMEOUT_MS = 10_000;
const DEFAULT_MAX_BYTES = 5 * 1024 * 1024; // 5MB of HTML is plenty for a recipe page

export class UrlNotAllowedError extends Error {
  readonly statusCode = 400;
  constructor(message: string) {
    super(message);
    this.name = "UrlNotAllowedError";
  }
}

function normalizeHostname(hostname: string): string {
  // URL hostnames are already lowercased; strip a trailing dot (FQDN form) and
  // surrounding brackets from IPv6 literals.
  return hostname.replace(/\.$/, "").replace(/^\[|\]$/g, "");
}

function hostnameAllowed(hostname: string): boolean {
  return ALLOWED_HOSTS.has(normalizeHostname(hostname));
}

/**
 * True for IPv4/IPv6 addresses that must never be fetched server-side:
 * loopback, private (RFC1918 / ULA), link-local, CGNAT, multicast, and other
 * non-public ranges. Input must already be a valid IP literal.
 */
export function isPrivateIp(ip: string): boolean {
  const kind = net.isIP(ip);
  if (kind === 4) return isPrivateIpv4(ip);
  if (kind === 6) return isPrivateIpv6(ip);
  // Not an IP at all — treat as unsafe rather than silently allowing.
  return true;
}

function isPrivateIpv4(ip: string): boolean {
  const parts = ip.split(".").map((p) => parseInt(p, 10));
  if (parts.length !== 4 || parts.some((n) => Number.isNaN(n) || n < 0 || n > 255)) {
    return true;
  }
  const [a, b] = parts;
  if (a === 0) return true; // 0.0.0.0/8 "this network"
  if (a === 10) return true; // private
  if (a === 127) return true; // loopback
  if (a === 169 && b === 254) return true; // link-local (incl. cloud metadata)
  if (a === 172 && b >= 16 && b <= 31) return true; // private
  if (a === 192 && b === 168) return true; // private
  if (a === 100 && b >= 64 && b <= 127) return true; // CGNAT 100.64/10
  if (a === 192 && b === 0 && parts[2] === 0) return true; // 192.0.0/24
  if (a === 198 && (b === 18 || b === 19)) return true; // benchmarking 198.18/15
  if (a >= 224) return true; // multicast (224/4) + reserved (240/4) + 255.255.255.255
  return false;
}

function isPrivateIpv6(ip: string): boolean {
  const addr = normalizeHostname(ip).toLowerCase();

  // IPv4-mapped / -compatible (::ffff:a.b.c.d or ::a.b.c.d) — validate the v4 part.
  const mapped = addr.match(/(?:^|:)((?:\d{1,3}\.){3}\d{1,3})$/);
  if (mapped) return isPrivateIpv4(mapped[1]);

  if (addr === "::" || addr === "::1") return true; // unspecified / loopback
  if (addr.startsWith("fe80") || addr.startsWith("fe9") || addr.startsWith("fea") || addr.startsWith("feb")) {
    return true; // link-local fe80::/10
  }
  if (/^f[cd]/.test(addr)) return true; // unique local fc00::/7
  if (addr.startsWith("ff")) return true; // multicast ff00::/8
  return false;
}

/**
 * Parse and validate a user-supplied URL against the scraper allowlist.
 * Throws {@link UrlNotAllowedError} on any URL that is malformed, uses a
 * non-HTTP scheme, targets a non-allowlisted host, or is a private IP literal.
 */
export function parseAllowedUrl(raw: unknown): URL {
  if (typeof raw !== "string" || raw.length === 0) {
    throw new UrlNotAllowedError("A url is required");
  }
  let url: URL;
  try {
    url = new URL(raw);
  } catch {
    throw new UrlNotAllowedError("Invalid url");
  }
  if (url.protocol !== "https:" && url.protocol !== "http:") {
    throw new UrlNotAllowedError("Only http(s) urls are supported");
  }
  if (!hostnameAllowed(url.hostname)) {
    throw new UrlNotAllowedError("Only nefisyemektarifleri.com URLs are supported");
  }
  // If the host is written as a raw IP literal, reject private ranges outright.
  const host = normalizeHostname(url.hostname);
  if (net.isIP(host) && isPrivateIp(host)) {
    throw new UrlNotAllowedError("URLs targeting private addresses are not allowed");
  }
  return url;
}

/**
 * Resolve a hostname and confirm every returned address is public. Guards
 * against an allowlisted name that (mis)resolves to a private address.
 */
async function assertResolvesToPublic(hostname: string): Promise<void> {
  const host = normalizeHostname(hostname);
  if (net.isIP(host)) {
    if (isPrivateIp(host)) {
      throw new UrlNotAllowedError("URLs targeting private addresses are not allowed");
    }
    return;
  }
  let addresses: { address: string }[];
  try {
    addresses = await lookup(host, { all: true });
  } catch {
    throw new UrlNotAllowedError("Could not resolve host");
  }
  if (addresses.length === 0 || addresses.some((a) => isPrivateIp(a.address))) {
    throw new UrlNotAllowedError("URLs targeting private addresses are not allowed");
  }
}

export interface SafeFetchOptions {
  headers?: Record<string, string>;
  timeoutMs?: number;
  maxBytes?: number;
}

/**
 * Fetch an allowlisted URL as text with SSRF protections: the URL and every
 * redirect hop are re-validated against the host allowlist and private-range
 * checks, redirects are bounded, the request is time-limited, and the response
 * body is size-capped.
 */
export async function safeFetchText(
  raw: unknown,
  options: SafeFetchOptions = {}
): Promise<{ text: string; finalUrl: string }> {
  const timeoutMs = options.timeoutMs ?? DEFAULT_TIMEOUT_MS;
  const maxBytes = options.maxBytes ?? DEFAULT_MAX_BYTES;

  let current = parseAllowedUrl(raw);

  for (let hop = 0; hop <= MAX_REDIRECTS; hop++) {
    await assertResolvesToPublic(current.hostname);

    const response = await fetch(current, {
      headers: options.headers,
      redirect: "manual", // follow manually so each hop is re-validated
      signal: AbortSignal.timeout(timeoutMs),
    });

    // Handle redirects ourselves, validating the destination each time.
    if (response.status >= 300 && response.status < 400) {
      const location = response.headers.get("location");
      if (!location) {
        throw new UrlNotAllowedError(`Redirect with no location (${response.status})`);
      }
      // Resolve relative redirects against the current URL, then re-validate.
      current = parseAllowedUrl(new URL(location, current).toString());
      continue;
    }

    if (!response.ok) {
      const err = new UrlNotAllowedError(`Failed to fetch page: ${response.status}`);
      // Upstream fetch failure is a 502, not a client error.
      (err as { statusCode: number }).statusCode = 502;
      throw err;
    }

    return { text: await readTextCapped(response, maxBytes), finalUrl: current.toString() };
  }

  throw new UrlNotAllowedError("Too many redirects");
}

async function readTextCapped(response: Response, maxBytes: number): Promise<string> {
  if (!response.body) return "";
  const reader = response.body.getReader();
  const chunks: Uint8Array[] = [];
  let total = 0;
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    if (value) {
      total += value.byteLength;
      if (total > maxBytes) {
        await reader.cancel();
        throw new UrlNotAllowedError("Response too large");
      }
      chunks.push(value);
    }
  }
  return Buffer.concat(chunks).toString("utf-8");
}
