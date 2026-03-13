Set-StrictMode -Version Latest

function Resolve-ExistingPath {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    return (Resolve-Path -LiteralPath $Path).Path
}

function Get-SteamInstallPath {
    $registryKeys = @(
        "HKCU:\Software\Valve\Steam",
        "HKLM:\Software\WOW6432Node\Valve\Steam",
        "HKLM:\Software\Valve\Steam"
    )

    foreach ($registryKey in $registryKeys) {
        try {
            $installPath = (Get-ItemProperty -Path $registryKey -Name InstallPath -ErrorAction Stop).InstallPath
            if ($installPath -and (Test-Path -LiteralPath $installPath)) {
                return (Resolve-ExistingPath -Path $installPath)
            }
        }
        catch {
        }
    }

    $fallbacks = @(
        (Join-Path ${env:ProgramFiles(x86)} "Steam"),
        (Join-Path $env:ProgramFiles "Steam"),
        (Join-Path $env:LOCALAPPDATA "Programs\Steam"),
        "C:\Steam",
        "D:\Steam",
        "E:\Steam"
    ) | Where-Object { $_ }

    $driveRoots = Get-PSDrive -PSProvider FileSystem | ForEach-Object { $_.Root }
    foreach ($driveRoot in $driveRoots) {
        $fallbacks += @(
            (Join-Path $driveRoot "Steam"),
            (Join-Path $driveRoot "SteamLibrary\Steam"),
            (Join-Path $driveRoot "Program Files (x86)\Steam"),
            (Join-Path $driveRoot "Program Files\Steam")
        )
    }

    foreach ($candidate in ($fallbacks | Select-Object -Unique)) {
        if ($candidate -and (Test-Path -LiteralPath $candidate)) {
            return (Resolve-ExistingPath -Path $candidate)
        }
    }

    return $null
}

function ConvertFrom-SteamVdfPath {
    param(
        [AllowNull()]
        [string]$Value
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $null
    }

    return $Value.Replace("\\", "\")
}

function Get-SteamLibraryPaths {
    param(
        [string]$SteamInstallPath
    )

    $steamRoot = $SteamInstallPath
    if ([string]::IsNullOrWhiteSpace($steamRoot)) {
        $steamRoot = Get-SteamInstallPath
    }

    if ([string]::IsNullOrWhiteSpace($steamRoot)) {
        return @()
    }

    $libraryPaths = [System.Collections.Generic.List[string]]::new()
    $libraryPaths.Add((Resolve-ExistingPath -Path $steamRoot))

    $libraryFoldersPath = Join-Path $steamRoot "steamapps\libraryfolders.vdf"
    if (Test-Path -LiteralPath $libraryFoldersPath) {
        $content = Get-Content -LiteralPath $libraryFoldersPath
        foreach ($line in $content) {
            if ($line -match '^\s*"path"\s*"(?<path>.+)"\s*$') {
                $path = ConvertFrom-SteamVdfPath -Value $Matches.path
                if ($path -and (Test-Path -LiteralPath $path)) {
                    $libraryPaths.Add((Resolve-ExistingPath -Path $path))
                }
                continue
            }

            if ($line -match '^\s*"\d+"\s*"(?<path>.+)"\s*$') {
                $path = ConvertFrom-SteamVdfPath -Value $Matches.path
                if ($path -and (Test-Path -LiteralPath $path)) {
                    $libraryPaths.Add((Resolve-ExistingPath -Path $path))
                }
            }
        }
    }

    return @($libraryPaths | Select-Object -Unique)
}

function Test-Sts2GameDir {
    param(
        [AllowNull()]
        [string]$Path
    )

    if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path -LiteralPath $Path)) {
        return $false
    }

    $exePath = Join-Path $Path "SlayTheSpire2.exe"
    return (Test-Path -LiteralPath $exePath)
}

function Resolve-Sts2GameDir {
    param(
        [string]$RequestedPath,
        [string]$SteamInstallPath,
        [switch]$AllowMissing
    )

    if (-not [string]::IsNullOrWhiteSpace($RequestedPath)) {
        if (Test-Sts2GameDir -Path $RequestedPath) {
            return (Resolve-ExistingPath -Path $RequestedPath)
        }

        throw "Slay the Spire 2 executable not found under '$RequestedPath'."
    }

    foreach ($libraryPath in (Get-SteamLibraryPaths -SteamInstallPath $SteamInstallPath)) {
        $commonDir = Join-Path $libraryPath "steamapps\common"
        if (-not (Test-Path -LiteralPath $commonDir)) {
            continue
        }

        $preferredPath = Join-Path $commonDir "Slay the Spire 2"
        if (Test-Sts2GameDir -Path $preferredPath) {
            return (Resolve-ExistingPath -Path $preferredPath)
        }

        $matches = Get-ChildItem -LiteralPath $commonDir -Directory -ErrorAction SilentlyContinue |
            Where-Object { Test-Sts2GameDir -Path $_.FullName } |
            Select-Object -First 1

        if ($matches) {
            return (Resolve-ExistingPath -Path $matches.FullName)
        }
    }

    if ($AllowMissing) {
        return $null
    }

    throw "Could not locate Slay the Spire 2 in any Steam library. Pass -GameDir to specify it manually."
}

function Resolve-Sts2ModsRoot {
    param(
        [Parameter(Mandatory)]
        [string]$GameDir
    )

    foreach ($candidate in @(
        (Join-Path $GameDir "mods"),
        (Join-Path $GameDir "Mods")
    )) {
        if (Test-Path -LiteralPath $candidate) {
            return (Resolve-ExistingPath -Path $candidate)
        }
    }

    return (Join-Path $GameDir "mods")
}

function Resolve-DotnetExecutable {
    $candidates = @()
    $candidates += "$env:USERPROFILE\.dotnet\dotnet.exe"

    $dotnetCommand = Get-Command dotnet -ErrorAction SilentlyContinue
    if ($dotnetCommand) {
        $candidates += $dotnetCommand.Source
    }

    $resolved = @($candidates | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -Unique)
    if (-not $resolved) {
        throw "dotnet executable not found."
    }

    return $resolved[0]
}

function Resolve-GodotExecutable {
    $candidates = @()

    $godotCommand = Get-Command godot -ErrorAction SilentlyContinue
    if ($godotCommand) {
        $candidates += $godotCommand.Source
    }

    $godot4Command = Get-Command godot4 -ErrorAction SilentlyContinue
    if ($godot4Command) {
        $candidates += $godot4Command.Source
    }

    $candidates += "D:\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"

    $resolved = @($candidates | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -Unique)
    if (-not $resolved) {
        throw "Godot executable not found."
    }

    return $resolved[0]
}

function Update-GodotAssetImports {
    param(
        [Parameter(Mandatory)]
        [string]$GodotExecutable,
        [Parameter(Mandatory)]
        [string]$ProjectRoot
    )

    if (-not (Test-Path -LiteralPath $ProjectRoot)) {
        throw "Project root not found: $ProjectRoot"
    }

    & $GodotExecutable --headless --editor --quit --path $ProjectRoot
    if ($LASTEXITCODE -ne 0) {
        throw "Godot asset import failed."
    }
}

function New-TemporarySyncerConfig {
    param(
        [Parameter(Mandatory)]
        [string]$ProjectRoot,
        [AllowNull()]
        [string]$GameDir,
        [AllowNull()]
        [string]$ModDir
    )

    $config = [ordered]@{
        collector_repo_dir = (Join-Path $ProjectRoot "collector")
        collector_output_dir = (Join-Path $ProjectRoot "collector\output\xhh")
    }

    if (-not [string]::IsNullOrWhiteSpace($GameDir)) {
        $config.game_dir = $GameDir
    }

    if (-not [string]::IsNullOrWhiteSpace($ModDir)) {
        $config.mod_dir = $ModDir
    }

    $tempFile = Join-Path ([System.IO.Path]::GetTempPath()) ("HeyboxCardStatsOverlay.syncer.{0}.json" -f [guid]::NewGuid().ToString("N"))
    $json = $config | ConvertTo-Json -Depth 4
    Set-Content -LiteralPath $tempFile -Value $json -Encoding UTF8
    return $tempFile
}

function Copy-DirectoryContents {
    param(
        [Parameter(Mandatory)]
        [string]$SourceDir,
        [Parameter(Mandatory)]
        [string]$DestinationDir
    )

    if (-not (Test-Path -LiteralPath $SourceDir)) {
        throw "Source directory not found: $SourceDir"
    }

    New-Item -ItemType Directory -Force -Path $DestinationDir | Out-Null

    foreach ($item in (Get-ChildItem -LiteralPath $SourceDir -Force -ErrorAction Stop)) {
        Copy-Item -LiteralPath $item.FullName -Destination $DestinationDir -Recurse -Force
    }
}

function Write-EffectiveModConfig {
    param(
        [Parameter(Mandatory)]
        [string]$SourcePath,
        [Parameter(Mandatory)]
        [string]$DestinationPath,
        [AllowNull()]
        [string]$RemoteDataUrl
    )

    $config = Get-Content -LiteralPath $SourcePath -Raw | ConvertFrom-Json
    if ($null -ne $RemoteDataUrl -and $RemoteDataUrl.Trim().Length -gt 0) {
        $config.remote_data_url = $RemoteDataUrl.Trim()
        $config.remote_data_enabled = $true
    }

    $json = $config | ConvertTo-Json -Depth 8
    Set-Content -LiteralPath $DestinationPath -Value $json -Encoding UTF8
}

function Set-PckCompatibilityHeader {
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        [int]$EngineMinorVersion = 5
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "PCK file not found: $Path"
    }

    [byte[]]$pckBytes = [System.IO.File]::ReadAllBytes($Path)
    if ($pckBytes.Length -lt 16) {
        throw "PCK header too small."
    }

    # Offsets 8-15 store the Godot engine version tuple. STS2 currently accepts 4.5.x packs.
    $pckBytes[8] = 4
    $pckBytes[9] = 0
    $pckBytes[10] = 0
    $pckBytes[11] = 0
    $pckBytes[12] = [byte]$EngineMinorVersion
    $pckBytes[13] = 0
    $pckBytes[14] = 0
    $pckBytes[15] = 0
    [System.IO.File]::WriteAllBytes($Path, $pckBytes)
}

function Get-PckCompatibilityHeader {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "PCK file not found: $Path"
    }

    [byte[]]$pckBytes = [System.IO.File]::ReadAllBytes($Path)
    if ($pckBytes.Length -lt 16) {
        throw "PCK header too small."
    }

    [pscustomobject]@{
        Major = [System.BitConverter]::ToInt32($pckBytes, 8)
        Minor = [System.BitConverter]::ToInt32($pckBytes, 12)
    }
}

function Assert-PckCompatibilityHeader {
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        [int]$ExpectedMajor = 4,
        [int]$MaxMinor = 5
    )

    $header = Get-PckCompatibilityHeader -Path $Path
    if ($header.Major -ne $ExpectedMajor -or $header.Minor -gt $MaxMinor) {
        throw "PCK compatibility header is $($header.Major).$($header.Minor), expected <= Godot $ExpectedMajor.$MaxMinor."
    }

    return $header
}
