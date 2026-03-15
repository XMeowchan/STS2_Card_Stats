const jsonHeaders = {
  "content-type": "application/json; charset=utf-8",
  "cache-control": "no-store",
  "access-control-allow-origin": "*",
  "access-control-allow-methods": "GET,POST,OPTIONS",
  "access-control-allow-headers": "content-type",
};

const textHeaders = {
  "content-type": "text/plain; charset=utf-8",
  "cache-control": "no-store",
  "access-control-allow-origin": "*",
  "access-control-allow-methods": "GET,POST,OPTIONS",
  "access-control-allow-headers": "content-type",
};

const kvBindingName = "TELEMETRY_KV";
const kvListLimit = 256;

export function handleOptions() {
  return new Response(null, { status: 204, headers: jsonHeaders });
}

export function jsonResponse(payload, status = 200) {
  return new Response(JSON.stringify(payload, null, 2), {
    status,
    headers: jsonHeaders,
  });
}

export function textResponse(text, status = 200) {
  return new Response(text, {
    status,
    headers: textHeaders,
  });
}

export function getTelemetryKv(context) {
  const kv = context?.env?.[kvBindingName] ?? globalThis?.[kvBindingName];
  if (!kv) {
    throw new Error(`Missing KV binding '${kvBindingName}'.`);
  }

  return kv;
}

export async function readJson(request) {
  try {
    return await request.json();
  } catch {
    throw new Error("Request body must be valid JSON");
  }
}

export function normalizeClientId(value) {
  const text = typeof value === "string" ? value.trim() : "";
  if (!/^[A-Za-z0-9_-]{16,80}$/.test(text)) {
    return "";
  }

  return text;
}

export function normalizeShortText(value, maxLength) {
  const text = typeof value === "string" ? value.trim() : "";
  if (text.length === 0) {
    return "";
  }

  return text.slice(0, maxLength);
}

export function normalizeIsoDateTime(value) {
  const text = typeof value === "string" ? value.trim() : "";
  if (text.length === 0) {
    return "";
  }

  const parsed = new Date(text);
  if (Number.isNaN(parsed.getTime())) {
    return "";
  }

  return parsed.toISOString();
}

export async function sha256Hex(value) {
  const encoded = new TextEncoder().encode(value);
  const digest = await crypto.subtle.digest("SHA-256", encoded);
  return Array.from(new Uint8Array(digest), (byte) =>
    byte.toString(16).padStart(2, "0"),
  ).join("");
}

export function utcDay(date = new Date()) {
  return date.toISOString().slice(0, 10);
}

export function compactDay(day) {
  return day.replaceAll("-", "");
}

export function expandCompactDay(value) {
  if (!/^\d{8}$/.test(value)) {
    return "";
  }

  return `${value.slice(0, 4)}-${value.slice(4, 6)}-${value.slice(6, 8)}`;
}

export function addDays(date, days) {
  const next = new Date(date);
  next.setUTCDate(next.getUTCDate() + days);
  return next;
}

export async function listKeys(kv, prefix) {
  const names = [];
  let cursor = undefined;

  do {
    const options = {
      prefix,
      limit: kvListLimit,
    };
    if (cursor) {
      options.cursor = cursor;
    }

    const page = await kv.list(options);

    for (const key of page.keys ?? []) {
      const keyName = key?.name ?? key?.key ?? "";
      if (keyName) {
        names.push(keyName);
      }
    }

    if (page.complete || !page.cursor) {
      cursor = undefined;
      break;
    }

    cursor = page.cursor;
  } while (cursor);

  return names;
}

export async function countKeys(kv, prefix) {
  let total = 0;
  let cursor = undefined;

  do {
    const options = {
      prefix,
      limit: kvListLimit,
    };
    if (cursor) {
      options.cursor = cursor;
    }

    const page = await kv.list(options);

    total += page.keys?.length ?? 0;

    if (page.complete || !page.cursor) {
      cursor = undefined;
      break;
    }

    cursor = page.cursor;
  } while (cursor);

  return total;
}

export function parseInstallDayKey(name) {
  const match = /^install_day_(\d{8})_[0-9a-f]{64}$/i.exec(name);
  return match ? expandCompactDay(match[1]) : "";
}
