#define MyAppName "الشامي (Alshami)"
#define MyAppVersion "1.0.0"
#define MyAppPublisher ""
#define MyAppURL ""
#define MyAppExeName "Alshami.exe"

[Setup]
AppId={{E8B2A4D6-C9F1-4A7E-8D3B-5F6C7A0E1B2C}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\Alshami
DefaultGroupName=الشامي
AllowNoIcons=yes
OutputDir=.
OutputBaseFilename=Alshami_Setup
SetupIconFile=windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#MyAppExeName}
UninstallDisplayName={#MyAppName}
PrivilegesRequired=admin
Compression=lzma2
SolidCompression=yes
ArchitecturesInstallIn64BitMode=x64compatible
DisableProgramGroupPage=yes
DisableWelcomePage=no

[Languages]
Name: "arabic"; MessagesFile: "compiler:Languages\Arabic.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "إنشاء اختصار على سطح المكتب"; GroupDescription: "اختصارات:"

[Files]
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs; Excludes: ".dart_tool"
Source: "VC_redist.x64.exe"; DestDir: "{tmp}"; Flags: deleteafterinstall

[Icons]
Name: "{autoprograms}\الشامي"; Filename: "{app}\{#MyAppExeName}"; WorkingDir: "{app}"
Name: "{autodesktop}\الشامي"; Filename: "{app}\{#MyAppExeName}"; WorkingDir: "{app}"; Tasks: desktopicon

[Run]
Filename: "taskkill"; Parameters: "/f /im Alshami.exe"; Flags: runhidden
Filename: "{tmp}\VC_redist.x64.exe"; Parameters: "/install /quiet /norestart"; StatusMsg: "جاري التحقق من مكتبات التشغيل الأساسية..."; Flags: runhidden
Filename: "netsh.exe"; Parameters: "advfirewall firewall add rule name=""Alshami-TCP-8080-In"" dir=in protocol=tcp localport=8080 action=allow profile=any"; Flags: runhidden
Filename: "netsh.exe"; Parameters: "advfirewall firewall add rule name=""Alshami-UDP-8081-In"" dir=in protocol=udp localport=8081 action=allow profile=any"; Flags: runhidden
Filename: "netsh.exe"; Parameters: "advfirewall firewall add rule name=""Alshami-UDP-8081-Out"" dir=out protocol=udp localport=8081 action=allow profile=any"; Flags: runhidden
Filename: "{app}\{#MyAppExeName}"; Description: "تشغيل التطبيق بعد التثبيت"; Flags: postinstall nowait skipifsilent

[UninstallRun]
Filename: "{cmd}"; Parameters: "/c taskkill /f /im Alshami.exe 2>nul"; Flags: runhidden; RunOnceId: "KillProcess"
; حذف أسماء القواعد الجديدة
Filename: "netsh.exe"; Parameters: "advfirewall firewall delete rule name=""Alshami-TCP-8080-In"""; Flags: runhidden; RunOnceId: "DeleteFirewallTCP"
Filename: "netsh.exe"; Parameters: "advfirewall firewall delete rule name=""Alshami-UDP-8081-In"""; Flags: runhidden; RunOnceId: "DeleteFirewallUDPIn"
Filename: "netsh.exe"; Parameters: "advfirewall firewall delete rule name=""Alshami-UDP-8081-Out"""; Flags: runhidden; RunOnceId: "DeleteFirewallUDPOut"
; حذف أسماء القواعد القديمة (للتوافق العكسي)
Filename: "netsh.exe"; Parameters: "advfirewall firewall delete rule name=""Alshami-TCP-8080"""; Flags: runhidden; RunOnceId: "DeleteFirewallTCP_Old"
Filename: "netsh.exe"; Parameters: "advfirewall firewall delete rule name=""Alshami-UDP-8081"""; Flags: runhidden; RunOnceId: "DeleteFirewallUDP_Old"
Filename: "{cmd}"; Parameters: "/c rmdir /s /q ""{userappdata}\Alshami"" 2>nul"; Flags: runhidden; RunOnceId: "DeleteAppDataRoaming"
Filename: "{cmd}"; Parameters: "/c rmdir /s /q ""{localappdata}\Alshami"" 2>nul"; Flags: runhidden; RunOnceId: "DeleteAppDataLocal"
Filename: "{cmd}"; Parameters: "/c rmdir /s /q ""{app}"" 2>nul"; Flags: runhidden; RunOnceId: "DeleteAppDir"
