param(
    [string]$GameDir,
    [string]$ModId = "HeyboxCardStatsOverlay"
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "Sts2InstallHelpers.ps1")

$resolvedGameDir = Resolve-Sts2GameDir -RequestedPath $GameDir
$modsRoot = Resolve-Sts2ModsRoot -GameDir $resolvedGameDir
$targetModDir = Join-Path $modsRoot $ModId
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"

$removedPaths = [System.Collections.Generic.List[string]]::new()
$updatedSettings = [System.Collections.Generic.List[string]]::new()

$cleanupPaths = [System.Collections.Generic.List[string]]::new()
$cleanupPaths.Add((Join-Path $targetModDir "_update_runtime"))

Get-ChildItem -LiteralPath $modsRoot -Directory -Filter "$ModId.backup-*" -ErrorAction SilentlyContinue |
    ForEach-Object {
        $cleanupPaths.Add($_.FullName)
    }

foreach ($cleanupPath in ($cleanupPaths | Select-Object -Unique)) {
    if (-not (Test-Path -LiteralPath $cleanupPath)) {
        continue
    }

    Remove-Item -LiteralPath $cleanupPath -Recurse -Force
    $removedPaths.Add($cleanupPath)
}

$settingsRoot = Join-Path $env:APPDATA "SlayTheSpire2\steam"
if (Test-Path -LiteralPath $settingsRoot) {
    $settingsFiles = Get-ChildItem -LiteralPath $settingsRoot -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -in @("settings.save", "settings.save.backup") }

    foreach ($settingsFile in $settingsFiles) {
        $settings = Get-Content -LiteralPath $settingsFile.FullName -Raw | ConvertFrom-Json
        if ($null -eq $settings.mod_settings) {
            continue
        }

        $disabledMods = @($settings.mod_settings.disabled_mods)
        if ($disabledMods.Count -eq 0) {
            continue
        }

        $filteredDisabledMods = @($disabledMods | Where-Object { $_.name -ne $ModId })
        if ($filteredDisabledMods.Count -eq $disabledMods.Count) {
            continue
        }

        Copy-Item -LiteralPath $settingsFile.FullName -Destination ($settingsFile.FullName + ".pre-repair-$timestamp.bak") -Force
        $settings.mod_settings.disabled_mods = $filteredDisabledMods
        $settings | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $settingsFile.FullName -Encoding UTF8
        $updatedSettings.Add($settingsFile.FullName)
    }
}

Write-Host "Detected game dir: $resolvedGameDir"
if ($removedPaths.Count -gt 0) {
    Write-Host "Removed duplicate mod artifacts:"
    $removedPaths | ForEach-Object { Write-Host " - $_" }
} else {
    Write-Host "No duplicate mod artifacts found."
}

if ($updatedSettings.Count -gt 0) {
    Write-Host "Cleared disabled_mods entries from:"
    $updatedSettings | ForEach-Object { Write-Host " - $_" }
} else {
    Write-Host "No disabled_mods entries needed cleanup."
}

Write-Host "Repair complete. Restart Slay the Spire 2 and re-open the mod list."
