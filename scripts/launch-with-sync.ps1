param(
    [string]$GameDir
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "Sts2InstallHelpers.ps1")

$resolvedGameDir = Resolve-Sts2GameDir -RequestedPath $GameDir
$syncScript = Join-Path $PSScriptRoot "sync-cards.ps1"
$gameExe = Join-Path $resolvedGameDir "SlayTheSpire2.exe"

if (!(Test-Path $gameExe)) {
    throw "Game executable not found: $gameExe"
}

try {
    & powershell -ExecutionPolicy Bypass -File $syncScript -GameDir $resolvedGameDir
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "sync-cards exited with code $LASTEXITCODE. Launching game with existing cache."
    }
}
catch {
    Write-Warning "sync-cards failed: $($_.Exception.Message). Launching game with existing cache."
}

Start-Process -FilePath $gameExe -WorkingDirectory $resolvedGameDir
