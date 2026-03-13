param(
    [string]$Configuration = "Release",
    [string]$GameDir,
    [string]$RemoteDataUrl,
    [switch]$IncludeCollector,
    [switch]$SkipBuild
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot

$payloadArgs = @(
    "-ExecutionPolicy", "Bypass",
    "-File", (Join-Path $PSScriptRoot "build-installer-payload.ps1"),
    "-Configuration", $Configuration
)
if ($RemoteDataUrl) {
    $payloadArgs += @("-RemoteDataUrl", $RemoteDataUrl)
}
if ($GameDir) {
    $payloadArgs += @("-GameDir", $GameDir)
}
if ($IncludeCollector) {
    $payloadArgs += "-IncludeCollector"
}
if ($SkipBuild) {
    $payloadArgs += "-SkipBuild"
}

& powershell @payloadArgs
if ($LASTEXITCODE -ne 0) {
    throw "build-installer-payload failed."
}

$manifest = Get-Content (Join-Path $projectRoot "mod_manifest.json") | ConvertFrom-Json
$payloadDir = Join-Path $projectRoot "dist\installer\payload"
$issPath = Join-Path $projectRoot "installer\HeyboxCardStatsOverlay.iss"

$isccCandidates = @()
$isccCommand = Get-Command ISCC.exe -ErrorAction SilentlyContinue
if ($isccCommand) {
    $isccCandidates += $isccCommand.Source
}
$isccCandidates += @(
    (Join-Path $env:LOCALAPPDATA "Programs\Inno Setup 6\ISCC.exe"),
    "C:\Program Files (x86)\Inno Setup 6\ISCC.exe",
    "C:\Program Files\Inno Setup 6\ISCC.exe"
)

$isccPath = $isccCandidates | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -First 1
if (-not $isccPath) {
    throw "Inno Setup 6 not found. Install ISCC.exe, then rerun .\scripts\build-installer.ps1."
}

& $isccPath "/DAppVersion=$($manifest.version)" "/DPayloadDir=$payloadDir" $issPath
if ($LASTEXITCODE -ne 0) {
    throw "ISCC failed."
}
