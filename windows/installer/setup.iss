; Inno Setup Script for MBADIFA SACCO
; This creates a Windows installer with desktop shortcut

#define MyAppName "MBADIFA SACCO"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "MBADIFA SACCO"
#define MyAppExeName "saccoplus_pro.exe"
#define MyAppDescription "Poverty Must Go - Financial Management System"

[Setup]
; App Information
AppId={{B7E8F9A2-3C4D-5E6F-7A8B-9C0D1E2F3A4B}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL=https://mbadifasacco.com
AppSupportURL=https://mbadifasacco.com/support
AppUpdatesURL=https://mbadifasacco.com/updates
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
AllowNoIcons=yes
OutputDir=..\..\build\windows\installer
OutputBaseFilename=MBADIFA_SACCO_Setup
SetupIconFile=..\..\windows\runner\resources\app_icon.ico
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=admin
ArchitecturesInstallIn64BitMode=x64

; UI Settings
DisableProgramGroupPage=yes
DisableWelcomePage=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: checkedonce
Name: "quicklaunchicon"; Description: "{cm:CreateQuickLaunchIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked; OnlyBelowVersion: 6.1; Check: not IsAdminInstallMode
Name: "startup"; Description: "Launch {#MyAppName} at Windows startup"; GroupDescription: "Startup:"; Flags: unchecked

[Files]
; Main executable and all DLLs
Source: "..\..\build\windows\x64\runner\Release\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\..\build\windows\x64\runner\Release\*.dll"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "..\..\build\windows\x64\runner\Release\data\*"; DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
; Start Menu shortcuts
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Comment: "{#MyAppDescription}"; IconFilename: "{app}\{#MyAppExeName}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"

; Desktop shortcut
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Comment: "{#MyAppDescription}"; Tasks: desktopicon; IconFilename: "{app}\{#MyAppExeName}"

; Quick Launch shortcut (for older Windows)
Name: "{userappdata}\Microsoft\Internet Explorer\Quick Launch\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: quicklaunchicon

; Startup shortcut (optional)
Name: "{userstartup}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: startup

[Run]
; Launch app after installation
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
; Clean up any created files
Type: filesandordirs; Name: "{app}\data"
Type: files; Name: "{app}\*.log"

[Code]
function InitializeSetup(): Boolean;
var
  ResultCode: Integer;
begin
  Result := True;
  
  // Check if app is running before installation
  if CheckForMutexes('MBADIFA_SACCO_MUTEX') then
  begin
    MsgBox('MBADIFA SACCO is currently running. Please close it before installing.', mbError, MB_OK);
    Result := False;
  end;
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then
  begin
    // Create any necessary registry entries here
    RegWriteStringValue(HKEY_CURRENT_USER, 'Software\MBADIFA_SACCO', 'InstallPath', ExpandConstant('{app}'));
    RegWriteStringValue(HKEY_CURRENT_USER, 'Software\MBADIFA_SACCO', 'Version', '{#MyAppVersion}');
  end;
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
  if CurUninstallStep = usPostUninstall then
  begin
    // Clean up registry
    RegDeleteKeyIncludingSubkeys(HKEY_CURRENT_USER, 'Software\MBADIFA_SACCO');
    
    // Ask if user wants to keep data
    if MsgBox('Do you want to remove all app data and settings?', mbConfirmation, MB_YESNO) = IDYES then
    begin
      DelTree(ExpandConstant('{userappdata}\MBADIFA_SACCO'), True, True, True);
    end;
  end;
end;
