[Setup]
AppName=SACCOPLUS
AppVersion=1.0.0
DefaultDirName={autopf}\SACCOPLUS
DefaultGroupName=SACCOPLUS
OutputDir=installer_output
OutputBaseFilename=SACCOPLUS_Setup
Compression=lzma2
SolidCompression=yes
PrivilegesRequired=admin
UninstallDisplayIcon={app}\saccoplus.exe
SetupIconFile=windows\runner\resources\app_icon.ico

[Files]
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs

[Icons]
Name: "{group}\SACCOPLUS"; Filename: "{app}\saccoplus.exe"
Name: "{autodesktop}\SACCOPLUS"; Filename: "{app}\saccoplus.exe"

[Run]
Filename: "{app}\saccoplus.exe"; Description: "Launch SACCOPLUS"; Flags: nowait postinstall skipifsilent
