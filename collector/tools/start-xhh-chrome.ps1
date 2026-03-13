param(
  [string]$UserDataDir = 'C:\xhh-collector-profile',
  [int]$RemoteDebuggingPort = 9222,
  [string]$ChromePath = ''
)

$databaseUrl = 'https://www.xiaoheihe.cn/game/slay_the_spire/database_v2/card_database'

function Resolve-ChromePath {
  param([string]$ExplicitPath)

  if ($ExplicitPath -and (Test-Path $ExplicitPath)) {
    return (Resolve-Path $ExplicitPath).Path
  }

  $candidates = @(
    "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
    "$env:ProgramFiles(x86)\Google\Chrome\Application\chrome.exe",
    "$env:LocalAppData\Google\Chrome\Application\chrome.exe",
    "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe",
    "$env:ProgramFiles(x86)\Microsoft\Edge\Application\msedge.exe"
  )

  foreach ($candidate in $candidates) {
    if (Test-Path $candidate) {
      return $candidate
    }
  }

  throw 'Could not find chrome.exe or msedge.exe automatically. Pass -ChromePath explicitly.'
}

$resolvedChrome = Resolve-ChromePath -ExplicitPath $ChromePath
New-Item -ItemType Directory -Force -Path $UserDataDir | Out-Null

$arguments = @(
  "--remote-debugging-port=$RemoteDebuggingPort",
  "--user-data-dir=$UserDataDir",
  '--start-minimized',
  $databaseUrl
)

Write-Host "Launching browser: $resolvedChrome"
Write-Host "User data dir: $UserDataDir"
Write-Host "Remote debugging port: $RemoteDebuggingPort"
Start-Process -FilePath $resolvedChrome -ArgumentList $arguments | Out-Null
