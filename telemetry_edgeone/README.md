# STS2 Card Stats Telemetry for EdgeOne

This folder contains a cheaper telemetry backend for the mod that keeps a custom domain without requiring you to buy a server.

- Runtime: EdgeOne Pages Functions
- Storage: EdgeOne KV
- Routes: `/v1/heartbeat` and `/v1/stats`
- Goal: keep the existing heartbeat and chart pipeline, but avoid relying on `workers.dev`

## Why this exists

Some users in mainland China cannot reliably reach `*.workers.dev`, so heartbeats never reach the telemetry database. This EdgeOne version is meant to be deployed behind your own custom domain and used as the primary endpoint, while the old Cloudflare Worker can stay as a fallback.

For the lowest-cost setup, create the Pages project in the `overseas` area. That keeps the custom domain path open without forcing you into the mainland ICP route. The tradeoff is that this is still overseas routing, not a mainland acceleration product.

## Layout

```text
telemetry_edgeone/
  edge-functions/
    index.js
    v1/
      heartbeat.js
      stats.js
```

## Deploy

1. Create an EdgeOne Pages project in the `overseas` area and point the project root at `telemetry_edgeone`.
2. Create a KV namespace and bind it as `TELEMETRY_KV`.
3. Add your custom domain `telemetry.xmeow.cn`.
4. Publish the project.

If you already created a `global`-area project for this repo, create a new project instead of reusing it. The deploy script now defaults to `sts2-card-stats-telemetry-overseas` for exactly that reason.

After deploy, the endpoints should look like this:

```text
https://telemetry.xmeow.cn/v1/heartbeat
https://telemetry.xmeow.cn/v1/stats?days=365
```

You can deploy with the included script:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\deploy-edgeone-telemetry.ps1
```

## Mod config

Put the domestic endpoint first and keep the old Worker as a fallback:

```json
{
  "telemetry_enabled": true,
  "telemetry_endpoints": [
    "https://telemetry.xmeow.cn/v1/heartbeat",
    "https://sts2-card-stats-telemetry.xmeowchan0415.workers.dev/v1/heartbeat"
  ],
  "telemetry_timeout_seconds": 5
}
```

The client still accepts the legacy `telemetry_endpoint` field, but `telemetry_endpoints` is now preferred.

## GitHub Pages chart

Set the repository variable `TELEMETRY_STATS_URL` to the new stats endpoint:

```text
https://telemetry.xmeow.cn/v1/stats?days=365
```

The existing Pages workflow already reads this variable.

## Data model

- `client_<hash>`: one key per anonymous installation
- `install_day_<yyyymmdd>_<hash>`: first-seen marker for cumulative installs
- `activity_<yyyymmdd>_<hash>`: one daily heartbeat per installation

Stats are derived from KV keys, so there is no separate SQL database to maintain.

The runtime code checks both `context.env.TELEMETRY_KV` and the injected global binding, because EdgeOne Pages may expose KV bindings differently depending on runtime mode.

## Notes

- EdgeOne KV is eventually consistent, so a freshly received heartbeat can take a short time to appear in `/v1/stats`.
- For production traffic in China, use a custom domain instead of a default preview domain.
- If you want to avoid ICP filing, keep the Pages project in the `overseas` area.
- If you later want mainland-China acceleration on your own domain, that is a different setup and may require ICP filing.
