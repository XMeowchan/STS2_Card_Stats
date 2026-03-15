param(
    [string]$Configuration = "Release",
    [string]$PayloadRoot = $(Join-Path (Split-Path -Parent $PSScriptRoot) "dist\installer\payload"),
    [string]$GameDir,
    [string]$RemoteDataUrl,
    [switch]$IncludeCollector,
    [switch]$SkipBuild
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "Sts2InstallHelpers.ps1")

$projectRoot = Split-Path -Parent $PSScriptRoot
$modId = "HeyboxCardStatsOverlay"
$dataDir = Join-Path $projectRoot "data"
$buildOut = Join-Path $projectRoot "src\bin\$Configuration"
$stagedModDir = Join-Path $PayloadRoot $modId

if (-not $SkipBuild) {
    $buildArgs = @(
        "-ExecutionPolicy", "Bypass",
        "-File", (Join-Path $PSScriptRoot "build-mod-artifacts.ps1"),
        "-Configuration", $Configuration
    )
    if ($GameDir) {
        $buildArgs += @("-GameDir", $GameDir)
    }

    & powershell @buildArgs
    if ($LASTEXITCODE -ne 0) {
        throw "build-mod-artifacts failed."
    }
}

$requiredArtifacts = @(
    (Join-Path $buildOut "$modId.dll"),
    (Join-Path $buildOut "$modId.pck")
)

foreach ($artifactPath in $requiredArtifacts) {
    if (-not (Test-Path -LiteralPath $artifactPath)) {
        throw "Missing build artifact: $artifactPath. Run .\scripts\deploy.ps1 or build the mod before staging the installer payload."
    }
}

Set-PckCompatibilityHeader -Path (Join-Path $buildOut "$modId.pck") -EngineMinorVersion 5
$pckHeader = Assert-PckCompatibilityHeader -Path (Join-Path $buildOut "$modId.pck") -ExpectedMajor 4 -MaxMinor 5
Write-Host ("Verified PCK compatibility header: Godot {0}.{1}" -f $pckHeader.Major, $pckHeader.Minor)

if (Test-Path -LiteralPath $stagedModDir) {
    Remove-Item -LiteralPath $stagedModDir -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $stagedModDir | Out-Null

Copy-Item (Join-Path $buildOut "$modId.dll") (Join-Path $stagedModDir "$modId.dll") -Force
Copy-Item (Join-Path $buildOut "$modId.pck") (Join-Path $stagedModDir "$modId.pck") -Force
Set-PckCompatibilityHeader -Path (Join-Path $stagedModDir "$modId.pck") -EngineMinorVersion 5
Copy-Item (Join-Path $projectRoot "mod_manifest.json") (Join-Path $stagedModDir "mod_manifest.json") -Force
Write-EffectiveModConfig -SourcePath (Join-Path $projectRoot "config.json") -DestinationPath (Join-Path $stagedModDir "config.json") -RemoteDataUrl $RemoteDataUrl
Copy-Item (Join-Path $projectRoot "sample_data\cards.sample.json") (Join-Path $stagedModDir "cards.sample.json") -Force

$repairDir = Join-Path $stagedModDir "_repair"
New-Item -ItemType Directory -Force -Path $repairDir | Out-Null
Copy-Item (Join-Path $PSScriptRoot "repair-local-mod-state.ps1") (Join-Path $repairDir "repair-local-mod-state.ps1") -Force
Copy-Item (Join-Path $PSScriptRoot "Sts2InstallHelpers.ps1") (Join-Path $repairDir "Sts2InstallHelpers.ps1") -Force

$bundledCandidates = @(
    (Join-Path $dataDir "cards.json"),
    (Join-Path $dataDir "cards.fallback.json"),
    (Join-Path $projectRoot "sample_data\cards.sample.json")
)
$bundledSource = $bundledCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $bundledSource) {
    throw "No bundled card data source found."
}

Copy-Item $bundledSource (Join-Path $stagedModDir "cards.fallback.json") -Force

$liveDataPath = Join-Path $dataDir "cards.json"
if (Test-Path -LiteralPath $liveDataPath) {
    Copy-Item $liveDataPath (Join-Path $stagedModDir "cards.json") -Force
} else {
    Copy-Item $bundledSource (Join-Path $stagedModDir "cards.json") -Force
}

$syncStatePath = Join-Path $dataDir "sync_state.json"
if (Test-Path -LiteralPath $syncStatePath) {
    Copy-Item $syncStatePath (Join-Path $stagedModDir "sync_state.json") -Force
}

$stagedDllPath = Join-Path $stagedModDir "$modId.dll"
if ((Test-CodeSigningConfigured) -and (-not (Test-AuthenticodeSignatureValid -Path $stagedDllPath))) {
    Invoke-AuthenticodeCodeSigning -Path $stagedDllPath -Description "Heybox Card Stats Overlay"
}

if ($IncludeCollector) {
    $collectorDir = Join-Path $projectRoot "collector"
    $stagedCollectorDir = Join-Path $stagedModDir "_collector"
    if (Test-Path -LiteralPath $stagedCollectorDir) {
        Remove-Item -LiteralPath $stagedCollectorDir -Recurse -Force
    }
    if (Test-Path -LiteralPath $collectorDir) {
        Copy-Item $collectorDir $stagedCollectorDir -Recurse -Force
    }
}

Write-Host "Staged installer payload: $stagedModDir"
