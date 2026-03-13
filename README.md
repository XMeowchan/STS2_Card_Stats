# HeyboxCardStatsOverlay

STS2 Mod that adds a XiaoHeiHe stats panel beside hovered cards.

## 更新卡牌数据

如果你只是想更新 GitHub Pages 上给 Mod 拉取的卡牌数据，正常流程是：

1. 先把最新采集结果同步进本仓库：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\sync-cards.ps1
```

2. 确认这些文件已经刷新：

- `data/cards.json`
- `data/cards.fallback.json`
- `data/sync_state.json`

3. 把改动提交并推送到 `main`。

4. GitHub Actions 会自动重新发布 Pages，线上数据地址是：

```text
https://xmeowchan.github.io/STS2_Card_Stats/cards.json
```

如果你只是更新线上数据，通常不需要重新打安装包。

只有在下面这些情况里，才建议重新打包并更新 Release：

- 你希望新安装的用户拿到最新离线数据
- Mod 代码、界面、配置项发生了变化
- `cards.json` 的结构或兼容策略有改动

重新打安装包用：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build-installer.ps1
```

## Local data flow

- The mod reads `cards.json` from its deployed mod folder.
- If `remote_data_enabled` and `remote_data_url` are configured, the mod will try to refresh `cards.json` from that URL in the background.
- If remote refresh fails or is disabled, the mod falls back to local shipped data: `cards.json`, then `cards.fallback.json`, then `cards.sample.json`.
- `scripts/sync-cards.ps1` is now a developer-side import step only. End users do not need it.
- `syncer.config.json` is kept as a sample config, but the main scripts now generate their runtime paths automatically.

## Embedded collector

- The collector is vendored into `collector/`.
- Collector output lives in `collector/output/xhh/` and is imported into the mod by `scripts/sync-cards.ps1`.
- The default installer payload no longer ships the collector to end users.

## Build and deploy

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\deploy.ps1
```

`deploy.ps1` now auto-detects the Steam install of `Slay the Spire 2`. If detection fails, pass `-GameDir "D:\path\to\Slay the Spire 2"` manually.
If you want the local test build to auto-refresh from GitHub Pages, also pass `-RemoteDataUrl "https://xmeowchan.github.io/STS2_Card_Stats/cards.json"`.

## Import latest collector output

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\sync-cards.ps1
```

If the game is installed, `sync-cards.ps1` also auto-detects the mod folder and mirrors the refreshed cache there.

## Stage end-user installer payload

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build-installer-payload.ps1
```

This collects the built DLL, PCK, offline data, and config into `dist\installer\payload\HeyboxCardStatsOverlay\`.
If you also want to ship the embedded collector tools, add `-IncludeCollector`.

## Build Windows installer

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build-installer.ps1
```

This requires Inno Setup 6 (`ISCC.exe`) and produces an installer in `dist\installer\output\`. The installer auto-detects the `Slay the Spire 2` Steam folder and copies the mod into the game's `mods` folder.

The installer does not run the sync pipeline on the user's machine. It only installs the mod plus bundled data files.
If you want the shipped mod to refresh from GitHub Pages, build with:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build-installer.ps1 -RemoteDataUrl "https://xmeowchan.github.io/STS2_Card_Stats/cards.json"
```

## Build GitHub Pages data

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build-pages-data.ps1
```

This creates `dist\pages\cards.json` and `dist\pages\index.html`. You can publish that folder with GitHub Pages and then set these fields in `config.json`:

```json
{
  "remote_data_enabled": true,
  "remote_data_url": "https://xmeowchan.github.io/STS2_Card_Stats/cards.json",
  "remote_refresh_minutes": 180,
  "remote_timeout_seconds": 5
}
```

With that enabled, the mod tries to refresh from GitHub Pages when the user has network access, and falls back to local bundled data when it does not.

## Remote repo

- The default remote source is `https://xmeowchan.github.io/STS2_Card_Stats/cards.json`.
- For the collector repo itself, a self-contained Pages exporter and workflow template were added under `collector/tools/export-pages-data.mjs`, `collector/.github/workflows/deploy-pages.yml`, and `collector/PAGES_README.md`.

## Data contract

Use the JSON structure recommended in `STS2_XiaoHeiHe_Data_Research.md`, for example:

```json
{
  "source": "xiaoheihe",
  "game": "slay_the_spire_2",
  "updated_at": "2026-03-12T10:25:00Z",
  "cards": [
    {
      "id": "Offering",
      "name_cn": "祭品",
      "name_en": "Offering",
      "stats": {
        "win_rate": 64.5,
        "pick_rate": 62.4,
        "skip_rate": 37.6,
        "times_won": 79275,
        "times_lost": 43574,
        "times_picked": 108556,
        "times_skipped": 65527,
        "win_rate_rank": 83,
        "pick_rate_rank": 10
      }
    }
  ]
}
```
