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

export default {
  async fetch(request, env) {
    try {
      if (request.method === "OPTIONS") {
        return new Response(null, { status: 204, headers: jsonHeaders });
      }

      const url = new URL(request.url);
      if (request.method === "GET" && url.pathname === "/") {
        return jsonResponse({
          ok: true,
          service: "sts2-card-stats-telemetry",
          endpoints: ["/v1/heartbeat", "/v1/stats.json"],
        });
      }

      if (request.method === "POST" && url.pathname === "/v1/heartbeat") {
        return handleHeartbeat(request, env);
      }

      if (request.method === "GET" && url.pathname === "/v1/stats.json") {
        return handleStats(url, env);
      }

      return new Response("Not found", { status: 404, headers: textHeaders });
    } catch (error) {
      return jsonResponse(
        {
          ok: false,
          error: error instanceof Error ? error.message : "Unexpected error",
        },
        500,
      );
    }
  },
};

async function handleHeartbeat(request, env) {
  let payload;
  try {
    payload = await readJson(request);
  } catch (error) {
    return jsonResponse(
      {
        ok: false,
        error: error instanceof Error ? error.message : "Request body must be valid JSON",
      },
      400,
    );
  }

  const clientId = normalizeClientId(payload.client_id);
  if (!clientId) {
    return jsonResponse({ ok: false, error: "client_id is required" }, 400);
  }

  const modId = normalizeShortText(payload.mod_id, 80) || "HeyboxCardStatsOverlay";
  const modVersion = normalizeShortText(payload.mod_version, 40) || "0.0.0";
  const platform = normalizeShortText(payload.platform, 40) || "unknown";
  const sentAt = normalizeIsoDateTime(payload.sent_at);
  const now = new Date();
  const nowIso = now.toISOString();
  const day = nowIso.slice(0, 10);
  const clientHash = await sha256Hex(`${modId}:${clientId}`);

  await env.DB.prepare(
    "INSERT OR IGNORE INTO installs (client_hash, first_seen_day, created_at) VALUES (?1, ?2, ?3)",
  )
    .bind(clientHash, day, nowIso)
    .run();

  const activityResult = await env.DB.prepare(
    "INSERT OR IGNORE INTO daily_activity (day, client_hash, mod_version, platform, created_at) VALUES (?1, ?2, ?3, ?4, ?5)",
  )
    .bind(day, clientHash, modVersion, platform, nowIso)
    .run();

  return jsonResponse(
    {
      ok: true,
      day,
      accepted: (activityResult.meta?.changes ?? 0) > 0,
      received_at: nowIso,
      sent_at: sentAt,
    },
    202,
  );
}

async function handleStats(url, env) {
  const requestedDays = Number.parseInt(url.searchParams.get("days") ?? "365", 10);
  const rangeDays = Number.isFinite(requestedDays)
    ? Math.max(30, Math.min(730, requestedDays))
    : 365;

  const result = await env.DB.prepare(`
    WITH daily_new AS (
      SELECT first_seen_day AS day, COUNT(*) AS new_users
      FROM installs
      GROUP BY first_seen_day
    ),
    daily_active AS (
      SELECT day, COUNT(*) AS active_users
      FROM daily_activity
      GROUP BY day
    ),
    all_days AS (
      SELECT day FROM daily_new
      UNION
      SELECT day FROM daily_active
    ),
    combined AS (
      SELECT
        all_days.day AS day,
        COALESCE(daily_new.new_users, 0) AS new_users,
        COALESCE(daily_active.active_users, 0) AS active_users
      FROM all_days
      LEFT JOIN daily_new ON daily_new.day = all_days.day
      LEFT JOIN daily_active ON daily_active.day = all_days.day
    )
    SELECT
      day,
      new_users,
      active_users,
      SUM(new_users) OVER (ORDER BY day ROWS UNBOUNDED PRECEDING) AS cumulative_users
    FROM combined
    ORDER BY day
  `).all();

  const rows = normalizeDailyRows(result.results ?? []);
  const trimmed = trimSeries(rows, rangeDays);
  const latest = trimmed.length > 0 ? trimmed[trimmed.length - 1] : null;

  return jsonResponse({
    ok: true,
    generated_at: new Date().toISOString(),
    range_days: rangeDays,
    total_installations: latest?.cumulative_users ?? 0,
    latest,
    days: trimmed,
  });
}

function normalizeDailyRows(rows) {
  if (!Array.isArray(rows) || rows.length === 0) {
    return [];
  }

  const parsed = rows
    .map((row) => ({
      day: String(row.day),
      new_users: toInt(row.new_users),
      active_users: toInt(row.active_users),
      cumulative_users: toInt(row.cumulative_users),
    }))
    .sort((left, right) => left.day.localeCompare(right.day));

  const byDay = new Map(parsed.map((row) => [row.day, row]));
  const start = new Date(`${parsed[0].day}T00:00:00Z`);
  const end = new Date(`${parsed[parsed.length - 1].day}T00:00:00Z`);
  const filled = [];
  let cumulativeUsers = 0;

  for (let cursor = new Date(start); cursor <= end; cursor = addDays(cursor, 1)) {
    const day = cursor.toISOString().slice(0, 10);
    const row = byDay.get(day);
    if (row) {
      cumulativeUsers = row.cumulative_users;
      filled.push(row);
      continue;
    }

    filled.push({
      day,
      new_users: 0,
      active_users: 0,
      cumulative_users: cumulativeUsers,
    });
  }

  return filled;
}

function trimSeries(rows, rangeDays) {
  if (rows.length <= rangeDays) {
    return rows;
  }

  return rows.slice(rows.length - rangeDays);
}

function normalizeClientId(value) {
  const text = typeof value === "string" ? value.trim() : "";
  if (!/^[A-Za-z0-9_-]{16,80}$/.test(text)) {
    return "";
  }

  return text;
}

function normalizeShortText(value, maxLength) {
  const text = typeof value === "string" ? value.trim() : "";
  if (text.length === 0) {
    return "";
  }

  return text.slice(0, maxLength);
}

function normalizeIsoDateTime(value) {
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

async function readJson(request) {
  try {
    return await request.json();
  } catch {
    throw new Error("Request body must be valid JSON");
  }
}

async function sha256Hex(value) {
  const encoded = new TextEncoder().encode(value);
  const digest = await crypto.subtle.digest("SHA-256", encoded);
  return Array.from(new Uint8Array(digest), (byte) =>
    byte.toString(16).padStart(2, "0"),
  ).join("");
}

function toInt(value) {
  const parsed = Number.parseInt(String(value ?? 0), 10);
  return Number.isFinite(parsed) ? parsed : 0;
}

function addDays(date, days) {
  const next = new Date(date);
  next.setUTCDate(next.getUTCDate() + days);
  return next;
}

function jsonResponse(payload, status = 200) {
  return new Response(JSON.stringify(payload, null, 2), {
    status,
    headers: jsonHeaders,
  });
}
