param(
    [string]$GameDir,
    [string]$PayloadDir = $(Join-Path (Split-Path -Parent $PSScriptRoot) "dist\installer\payload"),
    [string]$ModId = "HeyboxCardStatsOverlay"
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "Sts2InstallHelpers.ps1")

$resolvedGameDir = Resolve-Sts2GameDir -RequestedPath $GameDir
$sourceModDir = Join-Path $PayloadDir $ModId
if (-not (Test-Path -LiteralPath $sourceModDir)) {
    throw "Installer payload not found: $sourceModDir"
}

$modsRoot = Resolve-Sts2ModsRoot -GameDir $resolvedGameDir
$targetModDir = Join-Path $modsRoot $ModId

New-Item -ItemType Directory -Force -Path $targetModDir | Out-Null

$transientPaths = @(
    (Join-Path $targetModDir "_sync_runtime"),
    (Join-Path $targetModDir "_collector")
)
foreach ($transientPath in $transientPaths) {
    if (Test-Path -LiteralPath $transientPath) {
        Remove-Item -LiteralPath $transientPath -Recurse -Force
    }
}

Copy-DirectoryContents -SourceDir $sourceModDir -DestinationDir $targetModDir

Write-Host "Detected game dir: $resolvedGameDir"
Write-Host "Installed $ModId to $targetModDir"
