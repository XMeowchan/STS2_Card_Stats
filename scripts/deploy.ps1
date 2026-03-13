param(
    [string]$GameDir,
    [string]$RemoteDataUrl,
    [string]$Configuration = "Release"
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot "Sts2InstallHelpers.ps1")

$srcDir = Join-Path $projectRoot "src"
$dataDir = Join-Path $projectRoot "data"
$modId = "HeyboxCardStatsOverlay"
$resolvedGameDir = Resolve-Sts2GameDir -RequestedPath $GameDir
$modDir = Join-Path (Resolve-Sts2ModsRoot -GameDir $resolvedGameDir) $modId
$dotnet = Resolve-DotnetExecutable
$godot = Resolve-GodotExecutable
$buildOut = Join-Path $srcDir "bin\$Configuration"
$dllPath = Join-Path $buildOut "$modId.dll"
$pckPath = Join-Path $buildOut "$modId.pck"

New-Item -ItemType Directory -Force -Path $buildOut | Out-Null
New-Item -ItemType Directory -Force -Path $modDir | Out-Null

try {
    & powershell -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "sync-cards.ps1") -GameDir $resolvedGameDir
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "sync-cards exited with code $LASTEXITCODE. Deploying with existing local cache."
    }
}
catch {
    Write-Warning "sync-cards failed: $($_.Exception.Message). Deploying with existing local cache."
}

& $dotnet build (Join-Path $srcDir "$modId.csproj") -c $Configuration -p:GameDir="$resolvedGameDir"
if ($LASTEXITCODE -ne 0) {
    throw "dotnet build failed."
}

Update-GodotAssetImports -GodotExecutable $godot -ProjectRoot $projectRoot

& $godot --headless --path $projectRoot --script (Join-Path $projectRoot "scripts\build_pck.gd") -- $pckPath
if ($LASTEXITCODE -ne 0) {
    throw "Godot pck build failed."
}

Set-PckCompatibilityHeader -Path $pckPath -EngineMinorVersion 5

Copy-Item $dllPath (Join-Path $modDir "$modId.dll") -Force
Copy-Item $pckPath (Join-Path $modDir "$modId.pck") -Force
Set-PckCompatibilityHeader -Path (Join-Path $modDir "$modId.pck") -EngineMinorVersion 5
Copy-Item (Join-Path $projectRoot "mod_manifest.json") (Join-Path $modDir "mod_manifest.json") -Force
Write-EffectiveModConfig -SourcePath (Join-Path $projectRoot "config.json") -DestinationPath (Join-Path $modDir "config.json") -RemoteDataUrl $RemoteDataUrl
Copy-Item (Join-Path $projectRoot "sample_data\cards.sample.json") (Join-Path $modDir "cards.sample.json") -Force

$bundledCandidates = @(
    (Join-Path $dataDir "cards.json"),
    (Join-Path $dataDir "cards.fallback.json"),
    (Join-Path $projectRoot "sample_data\cards.sample.json")
)
$bundledSource = $bundledCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $bundledSource) {
    throw "No bundled card data source found."
}

Copy-Item $bundledSource (Join-Path $modDir "cards.fallback.json") -Force

$liveDataPath = Join-Path $dataDir "cards.json"
$deployedLivePath = Join-Path $modDir "cards.json"
if (Test-Path $liveDataPath) {
    Copy-Item $liveDataPath $deployedLivePath -Force
} elseif (Test-Path $deployedLivePath) {
    Remove-Item $deployedLivePath -Force
}

$syncStatePath = Join-Path $dataDir "sync_state.json"
if (Test-Path $syncStatePath) {
    Copy-Item $syncStatePath (Join-Path $modDir "sync_state.json") -Force
}

if (Test-Path (Join-Path $modDir "_sync_runtime")) {
    Remove-Item (Join-Path $modDir "_sync_runtime") -Recurse -Force
}

if (Test-Path (Join-Path $modDir "_collector")) {
    Remove-Item (Join-Path $modDir "_collector") -Recurse -Force
}

Write-Host "Detected game dir: $resolvedGameDir"
Write-Host "Bundled offline cache: $bundledSource"
Write-Host "Deployed $modId to $modDir"
