param(
    [string]$StateRoot,
    [string]$SummaryPath,
    [switch]$Quiet
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "Sts2InstallHelpers.ps1")

try {
    $summary = Copy-Sts2VanillaSavesToModded -StateRoot $StateRoot

    if (-not [string]::IsNullOrWhiteSpace($SummaryPath)) {
        $summaryJson = $summary | ConvertTo-Json -Depth 6
        Set-Content -LiteralPath $SummaryPath -Value $summaryJson -Encoding UTF8
    }

    if (-not $Quiet) {
        Write-Host "Save bootstrap state root: $($summary.StateRoot)"
        Write-Host "Steam user roots scanned: $($summary.UsersScanned)"
        Write-Host "Vanilla profiles with save files: $($summary.SourceProfilesFound)"
        Write-Host "Copied to empty modded profiles: $($summary.CopiedProfiles.Count)"
        foreach ($item in $summary.CopiedProfiles) {
            Write-Host " - Copied $($item.Profile) for $($item.UserId)"
        }

        Write-Host "Skipped because modded saves already exist: $($summary.SkippedExistingProfiles.Count)"
        foreach ($item in $summary.SkippedExistingProfiles) {
            Write-Host " - Skipped $($item.Profile) for $($item.UserId)"
        }
    }
}
catch {
    if (-not [string]::IsNullOrWhiteSpace($SummaryPath)) {
        $errorPayload = [ordered]@{
            error = $_.Exception.Message
        } | ConvertTo-Json -Depth 4
        Set-Content -LiteralPath $SummaryPath -Value $errorPayload -Encoding UTF8
    }

    throw
}
