param(
    [string]$Configuration = "Release",
    [string]$RemoteDataUrl,
    [switch]$IncludeCollector
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
if ($IncludeCollector) {
    $payloadArgs += "-IncludeCollector"
}

& powershell @payloadArgs
if ($LASTEXITCODE -ne 0) {
    throw "build-installer-payload failed."
}

$manifest = Get-Content (Join-Path $projectRoot "mod_manifest.json") | ConvertFrom-Json
$modId = $manifest.pck_name
if (-not $modId) {
    $modId = "HeyboxCardStatsOverlay"
}

$payloadDir = Join-Path $projectRoot "dist\installer\payload\$modId"
if (-not (Test-Path -LiteralPath $payloadDir)) {
    throw "Portable payload directory not found: $payloadDir"
}

$releaseDir = Join-Path $projectRoot "dist\release"
New-Item -ItemType Directory -Force -Path $releaseDir | Out-Null

$zipPath = Join-Path $releaseDir ("{0}-portable-{1}.zip" -f $modId, $manifest.version)
if (Test-Path -LiteralPath $zipPath) {
    Remove-Item -LiteralPath $zipPath -Force
}

Compress-Archive -Path $payloadDir -DestinationPath $zipPath -CompressionLevel Optimal
Write-Host "Built portable package: $zipPath"
