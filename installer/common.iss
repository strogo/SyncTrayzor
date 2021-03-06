#define AppExeName "SyncTrayzor.exe"
#define AppRoot "..\.."
#define AppSrc AppRoot + "\src\SyncTrayzor"
#define AppBin AppRoot +"\bin\" + Arch + "\Release"
#define AppExe AppBin + "\SyncTrayzor.exe"
#define AppName GetStringFileInfo(AppExe, "ProductName")
#define AppVersion GetFileVersion(AppExe)
#define AppPublisher "SyncTrayzor"
#define AppURL "https://github.com/canton7/SyncTrayzor"
#define AppDataFolder "SyncTrayzor"
#define RunRegKey "Software\Microsoft\Windows\CurrentVersion\Run"
#define DotNetInstallerExe "dotNet451Setup.exe"


[Setup]
AppId={{#AppId}
AppName={#AppName} ({#Arch})
AppVersion={#AppVersion}
;AppVerName={#AppName} {#AppVersion}
AppPublisher={#AppPublisher}
AppPublisherURL={#AppURL}
AppSupportURL={#AppURL}
AppUpdatesURL={#AppURL}
DefaultDirName={pf}\{#AppName}
DefaultGroupName={#AppName}
AllowNoIcons=yes
LicenseFile={#AppRoot}\LICENSE.txt
OutputDir="."
OutputBaseFilename={#AppName}Setup-{#Arch}
SetupIconFile={#AppSrc}\Icons\default.ico
Compression=lzma2/max
;Compression=None
SolidCompression=yes
PrivilegesRequired=admin
CloseApplications=yes
RestartApplications=no
; If we try and close CefSharp.BrowserSubprocess.exe we'll fail - it doesn't respond well
; However if we close *just* SyncTrayzor, that will take care of shutting down CefSharp and syncthing
CloseApplicationsFilter=SyncTrayzor.exe
TouchDate=current
#if "x64" == Arch
ArchitecturesInstallIn64BitMode=x64
ArchitecturesAllowed=x64
#endif

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[CustomMessages]
InstallingDotNetFramework=Installing .NET Framework. This might take a few minutes...
DotNetFrameworkFailedToLaunch=Failed to launch .NET Framework Installer with error "%1". Please fix the error then run this installer again.
DotNetFrameworkFailed1602=.NET Framework installation was cancelled. This installation can continue, but be aware that this application may not run unless the .NET Framework installation is completed successfully.
DotNetFrameworkFailed1603=A fatal error occurred while installing the .NET Framework. Please fix the error, then run the installer again.
DotNetFrameworkFailed5100=Your computer does not meet the requirements of the .NET Framework. Please consult the documentation.
DotNetFrameworkFailedOther=The .NET Framework installer exited with an unexpected status code "%1". Please review any other messages shown by the installer to determine whether the installation completed successfully, and abort this installation and fix the problem if it did not.

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Dirs]
Name: "{userappdata}\{#AppDataFolder}"

[Files]
; Near the beginning, as it's extracted first and this makes it cheaper
Source: "..\{#DotNetInstallerExe}"; DestDir: {tmp}; Flags: dontcopy nocompression noencryption

Source: "{#AppBin}\*"; DestDir: "{app}"; Excludes: "*.xml,*.vshost.*,*.config,*.log,FluentValidation.resources.dll,System.Windows.Interactivity.resources.dll,syncthing.exe,data,logs,ffmpegsumo.dll,d3dcompiler_43.dll,d3dcompiler_47.dll,libEGL.dll,libGLESv2.dll,pdf.dll"; Flags: ignoreversion recursesubdirs
Source: "{#AppBin}\SyncTrayzor.exe.Installer.config"; DestDir: "{app}"; DestName: "SyncTrayzor.exe.config"; Flags: ignoreversion
Source: "{#AppSrc}\Icons\default.ico"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#AppRoot}\*.md"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#AppRoot}\*.txt"; DestDir: "{app}"; Flags: ignoreversion
Source: "*.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "syncthing.exe"; DestDir: "{app}"; DestName: "syncthing.exe"; Flags: ignoreversion

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExeName}"
Name: "{group}\{cm:UninstallProgram,{#AppName}}"; Filename: "{uninstallexe}"
Name: "{commondesktop}\{#AppName}"; Filename: "{app}\{#AppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(AppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[Code]
var
  GlobalRestartRequired: boolean;

function DotNetIsMissing(): Boolean;
var 
  Exists: Boolean;
  Release: Cardinal;
begin
  Exists := RegQueryDWordValue(HKEY_LOCAL_MACHINE, 'SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full', 'Release', Release);
  Result := not Exists or (Release < 378758);
end;

// Adapted from https://blogs.msdn.microsoft.com/davidrickard/2015/07/17/installing-net-framework-4-5-automatically-with-inno-setup/
function InstallDotNet(): String;
var
  StatusText: string;
  ResultCode: Integer;
begin
  StatusText := WizardForm.StatusLabel.Caption;
  WizardForm.StatusLabel.Caption := CustomMessage('InstallingDotNetFramework');
  WizardForm.ProgressGauge.Style := npbstMarquee;
  try
    ExtractTemporaryFile('{#DotNetInstallerExe}');
    if not Exec(ExpandConstant('{tmp}\{#DotNetInstallerExe}'), '/passive /norestart /showrmui /showfinalerror', '', SW_SHOW, ewWaitUntilTerminated, ResultCode) then
    begin
      Result := FmtMessage(CustomMessage('DotNetFrameworkFailedToLaunch'), [SysErrorMessage(ResultCode)]);
    end
    else
    begin
      // See https://msdn.microsoft.com/en-us/library/ee942965(v=vs.110).aspx#return_codes
      case resultCode of
        0: begin
          // Successful
        end;
        1602 : begin
          MsgBox(CustomMessage('DotNetFrameworkFailed1602'), mbInformation, MB_OK);
        end;
        1603: begin
          Result := CustomMessage('DotNetFrameworkFailed1603');
        end;
        1641: begin
          GlobalRestartRequired := True;
        end;
        3010: begin
          GlobalRestartRequired := True;
        end;
        5100: begin
          Result := CustomMessage('DotNetFrameworkFailed5100');
        end;
        else begin
          MsgBox(FmtMessage(CustomMessage('DotNetFrameworkFailedOther'), [IntToStr(ResultCode)]), mbError, MB_OK);
        end;
      end;
    end;
  finally
    WizardForm.StatusLabel.Caption := StatusText;
    WizardForm.ProgressGauge.Style := npbstNormal;
  end;
end;

procedure BumpInstallCount;
var
  FileContents: AnsiString;
  InstallCount: integer;
begin
  { Increment the install count in InstallCount.txt if it exists, or create it with the contents '1' if it doesn't }
  if LoadStringFromFile(ExpandConstant('{app}\InstallCount.txt'), FileContents) then
  begin
    InstallCount := StrTointDef(Trim(string(FileContents)), 0) + 1;
  end
  else
  begin
    InstallCount := 1;
  end;

  SaveStringToFile(ExpandConstant('{app}\InstallCount.txt'), IntToStr(InstallCount), False);
end;

procedure CurStepChanged(CurStep: TSetupStep);
var
  FindRec: TFindRec;
  FolderPath: String;
  FilePath: String;
begin
  if CurStep = ssInstall then
  begin
    BumpInstallCount();

    { We might be being run from ProcessRunner.exe, *and* we might be trying to update it. Funsies. Let's rename it (which Windows lets us do) }
    DeleteFile(ExpandConstant('{app}\ProcessRunner.exe.old'));
    RenameFile(ExpandConstant('{app}\ProcessRunner.exe'), ExpandConstant('{app}\ProcessRunner.exe.old'));

    Log(ExpandConstant('Looking for resource files in {app}\*'));
    { Remove resource files. This means that out-of-date languages will be removed, which (as a last-ditch resore) will alert maintainers that something's wrong }
    if FindFirst(ExpandConstant('{app}\*'), FindRec) then
    begin
      try
        repeat
          if (FindRec.Attributes and FILE_ATTRIBUTE_DIRECTORY <> 0) and (FindRec.Name <> '.') and (FindRec.Name <> '..') then
          begin
            FolderPath :=  ExpandConstant('{app}\') + FindRec.Name;
            FilePath := FolderPath + '\SyncTrayzor.resources.dll';
            if DeleteFile(FilePath) then
            begin
              Log('Deleted ' + FilePath);
              if DelTree(FolderPath, True, False, False) then
                Log('Deleted ' + FolderPath);
            end;
          end;
        until not FindNext(FindRec);
      finally
        FindClose(FindRec);
      end;
    end;
  end
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
begin
  // 'NeedsRestart' only has an effect if we return a non-empty string, thus aborting the installation.
  // If the installers indicate that they want a restart, this should be done at the end of installation.
  // Therefore we set the global 'restartRequired' if a restart is needed, and return this from NeedRestart()

  if DotNetIsMissing() then
  begin
    Result := InstallDotNet();
  end;
end;

function NeedRestart(): Boolean;
begin
  Result := GlobalRestartRequired;
end;

[UninstallDelete]
Type: files; Name: "{app}\ProcessRunner.exe.old"
Type: files; Name: "{app}\InstallCount.txt"
Type: filesandordirs; Name: "{userappdata}\{#AppDataFolder}"
Type: filesandordirs; Name: "{localappdata}\{#AppDataFolder}"