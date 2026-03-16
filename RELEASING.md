# Releasing

This project ships two release artifacts:

- `HeyboxCardStatsOverlay-Setup-x.y.z.exe`
- `HeyboxCardStatsOverlay-portable-x.y.z.zip`

The portable zip must be attached to the GitHub Release. Player-side auto-update downloads that zip, not the installer exe.

## Local release flow

1. Update `mod_manifest.json` version.
2. Build release artifacts:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\publish-release.ps1
```

This will:

- build the portable zip
- build the installer exe
- sign the built DLL and installer exe if `CODESIGN_PFX_PATH` is set
- verify the PCK compatibility header stays at Godot 4.5
- generate release notes in `dist\release\`

## Optional code signing

If you have a PFX code-signing certificate, set these environment variables before building:

```powershell
$env:CODESIGN_PFX_PATH="C:\codesign\your-cert.pfx"
$env:CODESIGN_PFX_PASSWORD="your-pfx-password"
```

Optional:

```powershell
$env:CODESIGN_TIMESTAMP_URL="http://timestamp.digicert.com"
```

Without `CODESIGN_PFX_PATH`, the build still succeeds and simply skips signing.

## Optional GitHub upload

If GitHub CLI is installed and authenticated, you can upload both assets directly:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\publish-release.ps1 -Upload
```

The script will:

- create release `v<version>` if it does not exist
- otherwise upload and replace the existing assets

If `gh` is not installed, the same script can still upload by using `GITHUB_TOKEN` in the environment.

## GitHub Actions release workflow

This repo can also publish releases from GitHub Actions, but it should use a Windows self-hosted runner.

Reason:

- the mod builds against `sts2.dll`, `GodotSharp.dll`, and `0Harmony.dll` from the installed game
- installer packaging also depends on local Windows tools such as Inno Setup and Godot

The included workflow is:

- `.github/workflows/release-self-hosted.yml`

Recommended runner setup:

- Windows x64
- Slay the Spire 2 installed through Steam
- Inno Setup 6 installed
- Godot installed
- runner labels including `self-hosted`, `windows`, and `x64`

## Scheduled card data sync

This repo also includes a scheduled sync workflow:

- `.github/workflows/sync-card-data.yml`

It uses a Windows self-hosted runner because the collector attaches to a real logged-in Chrome/Edge profile over CDP.

Recommended runner setup:

- runner labels including `self-hosted`, `windows`, and `x64`
- Chrome or Edge installed
- a persistent browser profile already logged into the card data site
- the collector profile stored at `C:\xhh-collector-profile`, or override it with the `XHH_CHROME_USER_DATA_DIR` repository variable
- optional `XHH_CDP_URL` repository variable if the browser exposes a non-default CDP endpoint
- optional `XHH_ALERT_WEBHOOK` secret for login/failure alerts from the collector

Default schedule:

- every day at `02:45 UTC` (`10:45 UTC+8`) runs a full sync and pushes updated `data/` files when they change

You can also trigger the workflow manually from the Actions tab and choose either `full` or `keepalive`.

## Auto-update behavior

- Players must manually install the first version that includes the updater.
- After that, the mod checks the latest GitHub Release at startup.
- If a newer version exists, it downloads the portable zip in the background.
- The new files are copied into the mod folder after the game exits.
- The updater keeps the player's existing `config.json`.
