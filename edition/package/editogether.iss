; EdiTogether installer.
;
; Built by build-installer.ps1, which stages the application first. Produces
; a wizard that installs to Program Files, offers shortcuts and a project
; file association, registers with Add/Remove Programs, and uninstalls
; cleanly without leaving the user's projects behind.

#define AppName "EdiTogether"
#define AppPublisher "EdiTogether"
#define AppExeName "EdiTogether.cmd"
#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif
#ifndef StageDir
  #define StageDir "..\..\dist\EdiTogether"
#endif
#ifndef OutputDir
  #define OutputDir "..\..\dist"
#endif

[Setup]
AppId={{7C4C9E2A-6E4E-4C8B-9A1E-2E2E4E1B5D31}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher={#AppPublisher}
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
DisableDirPage=no
AllowNoIcons=yes
OutputDir={#OutputDir}
OutputBaseFilename=EdiTogether-{#AppVersion}-Setup
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
; A 64-bit application: install to the real Program Files, not the
; 32-bit redirect.
ArchitecturesInstallIn64BitMode=x64compatible
ArchitecturesAllowed=x64compatible
UninstallDisplayName={#AppName} {#AppVersion}
UninstallDisplayIcon={app}\qml.exe
LicenseFile={#StageDir}\LICENSE.txt
SetupLogging=yes
; The staged tree is large; say so before the copy starts.
DiskSpanning=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; \
    GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
Name: "associate"; Description: "Open .etproj project files with EdiTogether"; \
    GroupDescription: "File associations"
Name: "firewall"; Description: "Allow the collaboration relay through Windows Firewall (private networks)"; \
    GroupDescription: "Collaboration"; Flags: unchecked

[Files]
Source: "{#StageDir}\*"; DestDir: "{app}"; \
    Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExeName}"; \
    IconFilename: "{app}\qml.exe"; WorkingDir: "{app}"
Name: "{group}\Start collaboration relay"; Filename: "{app}\Start-Collaboration.cmd"; \
    IconFilename: "{app}\qml.exe"; WorkingDir: "{app}"
Name: "{group}\{cm:UninstallProgram,{#AppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExeName}"; \
    IconFilename: "{app}\qml.exe"; WorkingDir: "{app}"; Tasks: desktopicon

[Registry]
Root: HKA; Subkey: "Software\Classes\.etproj"; ValueType: string; \
    ValueName: ""; ValueData: "EdiTogether.Project"; \
    Flags: uninsdeletevalue; Tasks: associate
Root: HKA; Subkey: "Software\Classes\EdiTogether.Project"; ValueType: string; \
    ValueName: ""; ValueData: "EdiTogether Project"; \
    Flags: uninsdeletekey; Tasks: associate
Root: HKA; Subkey: "Software\Classes\EdiTogether.Project\DefaultIcon"; \
    ValueType: string; ValueName: ""; ValueData: "{app}\qml.exe,0"; Tasks: associate
Root: HKA; Subkey: "Software\Classes\EdiTogether.Project\shell\open\command"; \
    ValueType: string; ValueName: ""; \
    ValueData: """{app}\{#AppExeName}"" ""%1"""; Tasks: associate

[Run]
; Opening the firewall is opt-in: the relay binds loopback by default and
; only needs this when collaborators join from other machines.
Filename: "netsh"; \
    Parameters: "advfirewall firewall add rule name=""EdiTogether collaboration"" dir=in action=allow program=""{app}\tools\editogether-collab.exe"" enable=yes profile=private"; \
    StatusMsg: "Adding the firewall rule..."; Flags: runhidden; Tasks: firewall
Filename: "{app}\{#AppExeName}"; Description: "{cm:LaunchProgram,{#AppName}}"; \
    Flags: postinstall nowait skipifsilent shellexec

[UninstallRun]
Filename: "netsh"; \
    Parameters: "advfirewall firewall delete rule name=""EdiTogether collaboration"""; \
    Flags: runhidden; RunOnceId: "RemoveFirewallRule"

[UninstallDelete]
; Caches the application writes at runtime. Projects live in the user's own
; folders and are never touched.
Type: filesandordirs; Name: "{app}\cache"
Type: dirifempty; Name: "{app}"

[Code]
// Refuse to install onto an unsupported Windows rather than failing later
// with a missing-API error from the Qt runtime.
function InitializeSetup(): Boolean;
var
  Version: TWindowsVersion;
begin
  GetWindowsVersionEx(Version);
  if (Version.Major < 10) then
  begin
    MsgBox('EdiTogether needs Windows 10 or later.', mbCriticalError, MB_OK);
    Result := False;
    exit;
  end;
  Result := True;
end;
