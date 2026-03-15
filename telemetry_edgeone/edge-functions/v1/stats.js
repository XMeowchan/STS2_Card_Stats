import {
  addDays,
  compactDay,
  countKeys,
  getTelemetryKv,
  handleOptions,
  jsonResponse,
  listKeys,
  parseInstallDayKey,
  textResponse,
  utcDay,
} from "../_shared.js";

function clampRangeDays(value) {
  const parsed = Number.parseInt(value ?? "365", 10);
  if (!Number.isFinite(parsed)) {
    return 365;
  }

  return Math.max(30, Math.min(730, parsed));
}

function dateFromDay(day) {
  return new Date(`${day}T00:00:00Z`);
}

function buildInstallDayCounts(keys) {
  const counts = new Map();

  for (const key of keys) {
    const day = parseInstallDayKey(key);
    if (!day) {
      continue;
    }

    counts.set(day, (counts.get(day) ?? 0) + 1);
  }

  return counts;
}

async function loadActiveCounts(kv, startDay, endDay) {
  const counts = new Map();

  for (let cursor = dateFromDay(startDay); cursor <= dateFromDay(endDay); cursor = addDays(cursor, 1)) {
    const day = utcDay(cursor);
    const prefix = `activity_${compactDay(day)}_`;
    counts.set(day, await countKeys(kv, prefix));
  }

  return counts;
}

export default async function onRequest(context) {
  const { request } = context;

  if (request.method === "OPTIONS") {
    return handleOptions();
  }

  if (request.method !== "GET") {
    return textResponse("Method not allowed", 405);
  }

  try {
    const url = new URL(request.url);
    const rangeDays = clampRangeDays(url.searchParams.get("days"));
    const kv = getTelemetryKv(context);
    const installDayCounts = buildInstallDayCounts(await listKeys(kv, "install_day_"));
    const knownDays = [...installDayCounts.keys()].sort();

    if (knownDays.length === 0) {
      return jsonResponse({
        ok: true,
        generated_at: new Date().toISOString(),
        range_days: rangeDays,
        total_installations: 0,
        latest: null,
        days: [],
      });
    }

    const today = utcDay();
    const requestedEnd = dateFromDay(today);
    const requestedStart = addDays(requestedEnd, -(rangeDays - 1));
    const firstSeenDay = knownDays[0];
    const effectiveStart = requestedStart > dateFromDay(firstSeenDay) ? requestedStart : dateFromDay(firstSeenDay);
    const startDay = utcDay(effectiveStart);
    const activeCounts = await loadActiveCounts(kv, startDay, today);

    let cumulativeUsers = 0;
    for (const [day, count] of installDayCounts.entries()) {
      if (day < startDay) {
        cumulativeUsers += count;
      }
    }

    const rows = [];
    for (let cursor = effectiveStart; cursor <= requestedEnd; cursor = addDays(cursor, 1)) {
      const day = utcDay(cursor);
      const newUsers = installDayCounts.get(day) ?? 0;
      const activeUsers = activeCounts.get(day) ?? 0;
      cumulativeUsers += newUsers;
      rows.push({
        day,
        new_users: newUsers,
        active_users: activeUsers,
        cumulative_users: cumulativeUsers,
      });
    }

    const latest = rows.length > 0 ? rows[rows.length - 1] : null;

    return jsonResponse({
      ok: true,
      generated_at: new Date().toISOString(),
      range_days: rangeDays,
      total_installations: latest?.cumulative_users ?? 0,
      latest,
      days: rows,
    });
  } catch (error) {
    return jsonResponse(
      {
        ok: false,
        error: error instanceof Error ? error.message : "Unexpected error",
      },
      500,
    );
  }
}
