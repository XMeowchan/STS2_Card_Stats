param(
    [string]$Configuration = "Release",
    [string]$GameDir
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot "Sts2InstallHelpers.ps1")

$srcDir = Join-Path $projectRoot "src"
$modId = "HeyboxCardStatsOverlay"
$resolvedGameDir = Resolve-Sts2GameDir -RequestedPath $GameDir
$dotnet = Resolve-DotnetExecutable
$godot = Resolve-GodotExecutable
$buildOut = Join-Path $srcDir "bin\$Configuration"
$dllPath = Join-Path $buildOut "$modId.dll"
$pckPath = Join-Path $buildOut "$modId.pck"

New-Item -ItemType Directory -Force -Path $buildOut | Out-Null

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
$pckHeader = Assert-PckCompatibilityHeader -Path $pckPath -ExpectedMajor 4 -MaxMinor 5

foreach ($artifactPath in @($dllPath, $pckPath)) {
    if (-not (Test-Path -LiteralPath $artifactPath)) {
        throw "Missing build artifact: $artifactPath"
    }
}

Write-Host "Detected game dir: $resolvedGameDir"
Write-Host "Built DLL: $dllPath"
Write-Host ("Verified PCK compatibility header: Godot {0}.{1}" -f $pckHeader.Major, $pckHeader.Minor)
Write-Host "Built PCK: $pckPath"
