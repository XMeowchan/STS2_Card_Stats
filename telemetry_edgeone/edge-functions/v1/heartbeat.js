import {
  compactDay,
  getTelemetryKv,
  handleOptions,
  jsonResponse,
  normalizeClientId,
  normalizeIsoDateTime,
  normalizeShortText,
  readJson,
  sha256Hex,
  textResponse,
  utcDay,
} from "../_shared.js";

export default async function onRequest(context) {
  const { request } = context;

  if (request.method === "OPTIONS") {
    return handleOptions();
  }

  if (request.method !== "POST") {
    return textResponse("Method not allowed", 405);
  }

  try {
    const payload = await readJson(request);
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
    const day = utcDay(now);
    const dayToken = compactDay(day);
    const clientHash = await sha256Hex(`${modId}:${clientId}`);
    const kv = getTelemetryKv(context);

    const clientKey = `client_${clientHash}`;
    const installDayKey = `install_day_${dayToken}_${clientHash}`;
    const activityKey = `activity_${dayToken}_${clientHash}`;

    const existingClient = await kv.get(clientKey);
    if (existingClient === null) {
      await kv.put(
        clientKey,
        JSON.stringify({
          client_hash: clientHash,
          first_seen_day: day,
          created_at: nowIso,
          mod_id: modId,
        }),
      );
      await kv.put(
        installDayKey,
        JSON.stringify({
          client_hash: clientHash,
          first_seen_day: day,
          created_at: nowIso,
        }),
      );
    }

    const existingActivity = await kv.get(activityKey);
    const accepted = existingActivity === null;
    if (accepted) {
      await kv.put(
        activityKey,
        JSON.stringify({
          client_hash: clientHash,
          day,
          mod_version: modVersion,
          platform,
          sent_at: sentAt,
          created_at: nowIso,
        }),
      );
    }

    return jsonResponse(
      {
        ok: true,
        day,
        accepted,
        received_at: nowIso,
        sent_at: sentAt,
      },
      202,
    );
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
