# HeyboxCardStatsOverlay - Remaining Issues

Updated: 2026-03-13
Project root: `D:\dev\sts2-xiaoheihe-card-stats`
Game mod dir: `D:\Steam\steamapps\common\Slay the Spire 2\mods\HeyboxCardStatsOverlay`

## Current confirmed state

- The mod now loads successfully in-game.
- Latest game log confirms:
  - `Loaded 3 mods (3 total)`
  - `HeyboxCardStatsOverlay loaded from 'D:\Steam\steamapps\common\Slay the Spire 2\mods\HeyboxCardStatsOverlay'`
  - `HeyboxCardStatsOverlay: loaded 2 card ids from '...\cards.fallback.json' (fallback)`
  - `HeyboxCardStatsOverlay: native hover tip hook active for 'CARD.STRIKE_IRONCLAD'`
- The `.pck` header in the game mod dir is currently patched to the 4.5.1-compatible value (`05` at offset 12), so the game accepts it.
- The hover path is no longer blocked by the earlier `LocException` about a missing `common` table.

## What is still unresolved

### 1. Online sync is not authenticated

The syncer currently fails with:

- `status: "login_required"`
- `error_summary: "list sync requires an active XiaoHeiHe login in Edge."`

Files showing this state:

- `D:\dev\sts2-xiaoheihe-card-stats\data\sync_state.json`
- `D:\Steam\steamapps\common\Slay the Spire 2\mods\HeyboxCardStatsOverlay\sync_state.json`

This means the syncer reaches the XiaoHeiHe API path, but the browser context it launches does not have a usable logged-in XiaoHeiHe session.

### 2. Local fallback data is only sample-level

Current fallback file:

- `D:\Steam\steamapps\common\Slay the Spire 2\mods\HeyboxCardStatsOverlay\cards.fallback.json`

It only contains the sample `Offering / 祭品` entry, so most cards will still show the "no local data" text until a full online sync succeeds.

### 3. Syncer still uses Edge-derived browser state, but this is fragile across machines

Facts discovered during debugging:

- The current machine context is different from the earlier machine where the original research was done.
- The current syncer tries to work from the local Edge profile path:
  - `C:\Users\XMeow\AppData\Local\Microsoft\Edge\User Data\Default`
- A profile snapshot is created with `robocopy`, but `robocopy` can return exit code `9` and still be partially usable.
- Even after allowing partial snapshot continuation, the API still returns an auth-required state.

This strongly suggests that the current machine either:

- does not have a valid XiaoHeiHe login in the Edge profile the syncer is using, or
- has login artifacts that are not fully portable to the snapshot flow, or
- needs a dedicated persisted auth-state flow instead of copying a live browser profile.

## Most likely next engineering step

Stop depending on the live Edge profile for each sync attempt.

Recommended follow-up design:

1. Add a one-time auth bootstrap command, for example:
   - `save-auth-state.ps1`
2. Launch Edge or Chromium once, let the user log into XiaoHeiHe interactively.
3. Save a stable Playwright storage state file, for example:
   - `D:\dev\sts2-xiaoheihe-card-stats\data\xiaoheihe.auth.json`
4. Change `sync-cards.mjs` to prefer `storageState` from that saved auth file instead of trying to clone the active Edge profile every run.
5. Keep the current fallback behavior if auth is missing or expired.

This is the cleanest fix for both:

- cross-machine drift
- live-profile lock / partial snapshot issues

## Secondary follow-up after auth works

Once online sync succeeds, verify card ID coverage.

Current repository logic already tries multiple identifiers:

- `card.Id`
- `card.CanonicalInstance.Id`
- `card.GetType().Name`
- Pascal-cased variants derived from IDs
- `alt_ids`
- `name_en`
- `name_cn`

But this has not yet been validated against a full real `cards.json` from XiaoHeiHe.

After the first successful sync, test at least these cards:

- `StrikeIronclad`
- `DefendIronclad`
- `Bash`
- `PommelStrike`
- `Offering`

If any of them still miss, inspect the generated `cards.json` naming and add explicit mapping rules in `CardStatsRepository.cs`.

## Useful files for the next thread

### Mod-side

- `D:\dev\sts2-xiaoheihe-card-stats\src\HoverTipPatches.cs`
- `D:\dev\sts2-xiaoheihe-card-stats\src\HoverStatsTipBuilder.cs`
- `D:\dev\sts2-xiaoheihe-card-stats\src\CardStatsRepository.cs`
- `D:\dev\sts2-xiaoheihe-card-stats\src\CardStatsModels.cs`

### Syncer-side

- `D:\dev\sts2-xiaoheihe-card-stats\syncer\sync-cards.mjs`
- `D:\dev\sts2-xiaoheihe-card-stats\scripts\sync-cards.ps1`
- `D:\dev\sts2-xiaoheihe-card-stats\scripts\launch-with-sync.ps1`
- `D:\dev\sts2-xiaoheihe-card-stats\syncer.config.json`

### Runtime state

- `D:\dev\sts2-xiaoheihe-card-stats\data\sync_state.json`
- `D:\Steam\steamapps\common\Slay the Spire 2\mods\HeyboxCardStatsOverlay\sync_state.json`
- `C:\Users\XMeow\AppData\Roaming\SlayTheSpire2\logs\godot.log`

## Known-good baseline to avoid re-debugging

- The mod does currently load.
- The native hover hook does currently trigger.
- The `.pck` in the game mod dir currently has a compatible header (`05`), and the game accepts it.
- The remaining blocker is not mod loading; it is authenticated data acquisition.
