import { handleOptions, jsonResponse, textResponse } from "./_shared.js";

export default async function onRequest(context) {
  const { request } = context;

  if (request.method === "OPTIONS") {
    return handleOptions();
  }

  if (request.method !== "GET") {
    return textResponse("Method not allowed", 405);
  }

  return jsonResponse({
    ok: true,
    service: "sts2-card-stats-telemetry-edgeone",
    endpoints: ["/v1/heartbeat", "/v1/stats"],
  });
}
