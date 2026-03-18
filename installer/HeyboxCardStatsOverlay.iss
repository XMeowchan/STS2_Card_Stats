#ifndef AppName
  #define AppName "STS2 Card Stats Overlay"
#endif

#ifndef AppVersion
  #define AppVersion "0.2.12"
#endif

#ifndef ModId
  #define ModId "HeyboxCardStatsOverlay"
#endif

#ifndef PayloadDir
  #define PayloadDir "..\dist\installer\payload"
#endif

[Setup]
AppId={{8EB3D6B8-4853-4C89-93FA-7AE6BC968C37}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher=Rain_G | Codex
DefaultDirName={autopf}\{#AppName}
DisableDirPage=yes
DisableProgramGroupPage=yes
CreateAppDir=no
Uninstallable=no
OutputDir=..\dist\installer\output
OutputBaseFilename={#ModId}-Setup-{#AppVersion}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=admin
ArchitecturesInstallIn64BitMode=x64compatible

[Languages]
Name: "chinesesimp"; MessagesFile: "compiler:Default.isl"

[Files]
Source: "{#PayloadDir}\{#ModId}\*"; DestDir: "{code:GetTargetModDir}"; Flags: ignoreversion recursesubdirs createallsubdirs

[InstallDelete]
Type: filesandordirs; Name: "{code:GetTransientUpdateRuntimeDir}"
Type: filesandordirs; Name: "{code:GetTransientSyncRuntimeDir}"
Type: filesandordirs; Name: "{code:GetTransientCollectorDir}"
Type: files; Name: "{code:GetTargetModDir}\mod_manifest.json"
Type: files; Name: "{code:GetTargetModDir}\cards.json"
Type: files; Name: "{code:GetTargetModDir}\cards.fallback.json"
Type: files; Name: "{code:GetTargetModDir}\cards.sample.json"
Type: files; Name: "{code:GetTargetModDir}\sync_state.json"

[Code]
var
  GameDirPage: TInputDirWizardPage;
  ResolvedGameDir: string;

function NormalizeDir(const Value: string): string;
begin
  Result := RemoveBackslashUnlessRoot(Trim(Value));
end;

function PathJoin(const BasePath, ChildPath: string): string;
begin
  Result := AddBackslash(BasePath) + ChildPath;
end;

function IsNumericKey(const Value: string): Boolean;
var
  Index: Integer;
begin
  Result := Value <> '';
  if not Result then
    Exit;

  for Index := 1 to Length(Value) do
  begin
    if (Value[Index] < '0') or (Value[Index] > '9') then
    begin
      Result := False;
      Exit;
    end;
  end;
end;

function ExtractVdfValue(const Line: string): string;
var
  Remaining: string;
  Key: string;
  Value: string;
  QuotePos: Integer;
begin
  Result := '';
  Remaining := Trim(Line);
  if Remaining = '' then
    Exit;

  if Remaining[1] <> '"' then
    Exit;

  Delete(Remaining, 1, 1);
  QuotePos := Pos('"', Remaining);
  if QuotePos = 0 then
    Exit;

  Key := Copy(Remaining, 1, QuotePos - 1);
  Delete(Remaining, 1, QuotePos);
  Remaining := Trim(Remaining);
  if Remaining = '' then
    Exit;

  if Remaining[1] <> '"' then
    Exit;

  Delete(Remaining, 1, 1);
  QuotePos := Pos('"', Remaining);
  if QuotePos = 0 then
    Exit;

  Value := Copy(Remaining, 1, QuotePos - 1);
  if (CompareText(Key, 'path') = 0) or IsNumericKey(Key) then
  begin
    Result := Value;
    StringChangeEx(Result, '\\', '\', True);
  end;
end;

function IsSts2GameDir(const Candidate: string): Boolean;
var
  Normalized: string;
begin
  Normalized := NormalizeDir(Candidate);
  if Normalized = '' then
  begin
    Result := False;
    Exit;
  end;

  Result := DirExists(Normalized);
  if Result then
    Result := FileExists(PathJoin(Normalized, 'SlayTheSpire2.exe'));
end;

function FindSts2InLibraryRoot(const LibraryRoot: string): string;
var
  CommonDir: string;
  Candidate: string;
  FindRec: TFindRec;
begin
  Result := '';
  if LibraryRoot = '' then
    Exit;

  CommonDir := PathJoin(NormalizeDir(LibraryRoot), 'steamapps\common');
  if not DirExists(CommonDir) then
    Exit;

  Candidate := PathJoin(CommonDir, 'Slay the Spire 2');
  if IsSts2GameDir(Candidate) then
  begin
    Result := Candidate;
    Exit;
  end;

  if FindFirst(PathJoin(CommonDir, '*'), FindRec) then
  begin
    try
      repeat
        if ((FindRec.Attributes and FILE_ATTRIBUTE_DIRECTORY) <> 0) and
           (FindRec.Name <> '.') and
           (FindRec.Name <> '..') then
        begin
          Candidate := PathJoin(CommonDir, FindRec.Name);
          if IsSts2GameDir(Candidate) then
          begin
            Result := Candidate;
            Exit;
          end;
        end;
      until not FindNext(FindRec);
    finally
      FindClose(FindRec);
    end;
  end;
end;

function FindSts2FromSteamRoot(const SteamRoot: string): string;
var
  LibraryFoldersPath: string;
  Lines: TArrayOfString;
  Index: Integer;
  LibraryRoot: string;
begin
  Result := FindSts2InLibraryRoot(SteamRoot);
  if Result <> '' then
    Exit;

  LibraryFoldersPath := PathJoin(NormalizeDir(SteamRoot), 'steamapps\libraryfolders.vdf');
  if not FileExists(LibraryFoldersPath) then
    Exit;

  if not LoadStringsFromFile(LibraryFoldersPath, Lines) then
    Exit;

  for Index := 0 to GetArrayLength(Lines) - 1 do
  begin
    LibraryRoot := ExtractVdfValue(Lines[Index]);
    if LibraryRoot = '' then
      Continue;

    Result := FindSts2InLibraryRoot(LibraryRoot);
    if Result <> '' then
      Exit;
  end;
end;

function FindSteamRootFromRegistry(): string;
var
  Candidate: string;
begin
  Result := '';

  if RegQueryStringValue(HKCU, 'Software\Valve\Steam', 'InstallPath', Candidate) then
  begin
    if DirExists(Candidate) then
    begin
      Result := NormalizeDir(Candidate);
      Exit;
    end;
  end;

  if RegQueryStringValue(HKLM, 'Software\WOW6432Node\Valve\Steam', 'InstallPath', Candidate) then
  begin
    if DirExists(Candidate) then
    begin
      Result := NormalizeDir(Candidate);
      Exit;
    end;
  end;

  if RegQueryStringValue(HKLM, 'Software\Valve\Steam', 'InstallPath', Candidate) then
  begin
    if DirExists(Candidate) then
      Result := NormalizeDir(Candidate);
  end;
end;

function FindSteamRootFromFallbacks(): string;
var
  Candidate: string;
  DriveCode: Integer;
begin
  Result := '';

  Candidate := PathJoin(GetEnv('ProgramFiles(x86)'), 'Steam');
  if DirExists(Candidate) then
  begin
    Result := NormalizeDir(Candidate);
    Exit;
  end;

  Candidate := PathJoin(GetEnv('ProgramFiles'), 'Steam');
  if DirExists(Candidate) then
  begin
    Result := NormalizeDir(Candidate);
    Exit;
  end;

  Candidate := PathJoin(GetEnv('LOCALAPPDATA'), 'Programs\Steam');
  if DirExists(Candidate) then
  begin
    Result := NormalizeDir(Candidate);
    Exit;
  end;

  for DriveCode := Ord('C') to Ord('Z') do
  begin
    Candidate := Chr(DriveCode) + ':\Steam';
    if DirExists(Candidate) then
    begin
      Result := NormalizeDir(Candidate);
      Exit;
    end;

    Candidate := Chr(DriveCode) + ':\Program Files (x86)\Steam';
    if DirExists(Candidate) then
    begin
      Result := NormalizeDir(Candidate);
      Exit;
    end;

    Candidate := Chr(DriveCode) + ':\Program Files\Steam';
    if DirExists(Candidate) then
    begin
      Result := NormalizeDir(Candidate);
      Exit;
    end;
  end;
end;

function DetectSts2GameDir(): string;
var
  SteamRoot: string;
  DriveCode: Integer;
begin
  Result := '';

  SteamRoot := FindSteamRootFromRegistry();
  if SteamRoot = '' then
    SteamRoot := FindSteamRootFromFallbacks();

  if SteamRoot <> '' then
  begin
    Result := FindSts2FromSteamRoot(SteamRoot);
    if Result <> '' then
      Exit;
  end;

  for DriveCode := Ord('C') to Ord('Z') do
  begin
    Result := FindSts2InLibraryRoot(Chr(DriveCode) + ':\Steam');
    if Result <> '' then
      Exit;

    Result := FindSts2InLibraryRoot(Chr(DriveCode) + ':\SteamLibrary');
    if Result <> '' then
      Exit;

    Result := FindSts2InLibraryRoot(Chr(DriveCode) + ':\SteamLibrary\Steam');
    if Result <> '' then
      Exit;

    Result := FindSts2InLibraryRoot(Chr(DriveCode) + ':\Program Files (x86)\Steam');
    if Result <> '' then
      Exit;

    Result := FindSts2InLibraryRoot(Chr(DriveCode) + ':\Program Files\Steam');
    if Result <> '' then
      Exit;
  end;
end;

function ResolveRequestedGameDir(const RequestedPath: string): string;
var
  Candidate: string;
begin
  Candidate := NormalizeDir(RequestedPath);
  if Candidate = '' then
  begin
    Result := DetectSts2GameDir();
    Exit;
  end;

  if IsSts2GameDir(Candidate) then
  begin
    Result := Candidate;
    Exit;
  end;

  Result := PathJoin(Candidate, 'Slay the Spire 2');
  if IsSts2GameDir(Result) then
    Exit;

  Result := PathJoin(Candidate, 'steamapps\common\Slay the Spire 2');
  if IsSts2GameDir(Result) then
    Exit;

  Result := FindSts2InLibraryRoot(Candidate);
end;

function GetRequestedGameDir(): string;
begin
  Result := NormalizeDir(ExpandConstant('{param:GameDir|}'));
  if Result <> '' then
    Exit;

  if Assigned(GameDirPage) then
    Result := NormalizeDir(GameDirPage.Values[0])
  else
    Result := '';
end;

function ResolveGameDir(var ErrorMessage: string): Boolean;
var
  RequestedPath: string;
begin
  ErrorMessage := '';
  RequestedPath := GetRequestedGameDir();
  ResolvedGameDir := ResolveRequestedGameDir(RequestedPath);
  Result := ResolvedGameDir <> '';
  if Result then
  begin
    if Assigned(GameDirPage) and (ExpandConstant('{param:GameDir|}') = '') then
      GameDirPage.Values[0] := ResolvedGameDir;

    Log('Resolved Slay the Spire 2 game dir: ' + ResolvedGameDir);
    Exit;
  end;

  if RequestedPath = '' then
    ErrorMessage := 'Could not locate Slay the Spire 2 automatically. Browse to the folder that contains SlayTheSpire2.exe.'
  else
    ErrorMessage := 'Slay the Spire 2 executable was not found under "' + RequestedPath + '". Browse to the folder that contains SlayTheSpire2.exe.';
end;

function GetModsRoot(const GameDir: string): string;
begin
  Result := PathJoin(GameDir, 'mods');
  if DirExists(Result) then
    Exit;

  Result := PathJoin(GameDir, 'Mods');
  if DirExists(Result) then
    Exit;

  Result := PathJoin(GameDir, 'mods');
end;

function GetResolvedGameDir(): string;
var
  ErrorMessage: string;
begin
  if ResolvedGameDir = '' then
  begin
    if not ResolveGameDir(ErrorMessage) then
    begin
      Result := '';
      Exit;
    end;
  end;

  Result := ResolvedGameDir;
end;

function GetTargetModDir(Param: string): string;
var
  GameDir: string;
begin
  GameDir := GetResolvedGameDir();
  if GameDir = '' then
    Result := PathJoin(ExpandConstant('{tmp}'), '{#ModId}-pending')
  else
    Result := PathJoin(GetModsRoot(GameDir), '{#ModId}');
end;

function GetTransientSyncRuntimeDir(Param: string): string;
begin
  Result := PathJoin(GetTargetModDir(Param), '_sync_runtime');
end;

function GetTransientUpdateRuntimeDir(Param: string): string;
begin
  Result := PathJoin(GetTargetModDir(Param), '_update_runtime');
end;

function GetTransientCollectorDir(Param: string): string;
begin
  Result := PathJoin(GetTargetModDir(Param), '_collector');
end;

procedure InitializeWizard();
var
  DetectedGameDir: string;
begin
  ResolvedGameDir := '';
  GameDirPage :=
    CreateInputDirPage(
      wpWelcome,
      'Select Slay the Spire 2 folder',
      'Choose the game folder that contains SlayTheSpire2.exe',
      'The installer copies the mod into the game''s mods folder. If the detected path is wrong, browse to the correct folder.',
      False,
      '');
  GameDirPage.Add('Game folder:');

  DetectedGameDir := DetectSts2GameDir();
  if DetectedGameDir <> '' then
    GameDirPage.Values[0] := DetectedGameDir;
end;

function NextButtonClick(CurPageID: Integer): Boolean;
var
  ErrorMessage: string;
begin
  Result := True;
  if Assigned(GameDirPage) then
  begin
    if CurPageID = GameDirPage.ID then
    begin
      ResolvedGameDir := '';
      Result := ResolveGameDir(ErrorMessage);
      if not Result then
        MsgBox(ErrorMessage, mbError, MB_OK);
    end;
  end;
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
begin
  ResolvedGameDir := '';
  if ResolveGameDir(Result) then
    Result := '';
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then
    MsgBox('The mod has been installed successfully. Launch the game to use it.', mbInformation, MB_OK);
end;
