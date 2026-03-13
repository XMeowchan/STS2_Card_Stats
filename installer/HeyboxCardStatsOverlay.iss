#ifndef AppName
  #define AppName "XiaoHeiHe Card Stats Overlay"
#endif

#ifndef AppVersion
  #define AppVersion "0.2.1"
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
Source: "{#PayloadDir}\*"; DestDir: "{tmp}\payload"; Flags: ignoreversion recursesubdirs createallsubdirs deleteafterinstall
Source: "..\scripts\install-mod.ps1"; DestDir: "{tmp}"; Flags: ignoreversion deleteafterinstall
Source: "..\scripts\Sts2InstallHelpers.ps1"; DestDir: "{tmp}"; Flags: ignoreversion deleteafterinstall

[Code]
function InstallMod(): Boolean;
var
  ResultCode: Integer;
  Parameters: String;
begin
  Parameters :=
    '/C powershell.exe -NoProfile -ExecutionPolicy Bypass -File "' +
    ExpandConstant('{tmp}\install-mod.ps1') +
    '" -PayloadDir "' + ExpandConstant('{tmp}\payload') + '"';

  Result := Exec(ExpandConstant('{cmd}'), Parameters, '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  if (not Result) or (ResultCode <> 0) then
  begin
    if not Result then
      MsgBox('Failed to start the installer script. Please make sure PowerShell is available.', mbError, MB_OK)
    else
      MsgBox('Mod installation failed. Please make sure Slay the Spire 2 is installed via Steam and not currently running.', mbError, MB_OK);
    Result := False;
    Exit;
  end;

  MsgBox('The mod has been installed successfully. Launch the game to use it.', mbInformation, MB_OK);
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then
  begin
    if not InstallMod() then
      Abort();
  end;
end;
