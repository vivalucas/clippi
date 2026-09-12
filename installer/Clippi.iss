; Clippi Windows packaging script.
;
; Produces two self-contained executables from the same publish output:
;   - Clippi-Setup-x64.exe    standard per-user installer (Start menu + optional
;                             desktop shortcut, uninstaller)
;   - Clippi-Portable-x64.exe extract-once portable build (no shortcuts, no
;                             uninstaller, defaults to a "Clippi" folder next
;                             to the exe itself)
;
; Usage:
;   iscc /DAppVersion=1.2.0 /DSourcePath=build /DDistPath=dist installer\Clippi.iss
;   iscc /DPORTABLE /DAppVersion=1.2.0 /DSourcePath=build /DDistPath=dist installer\Clippi.iss
;
; WinUI 3 cannot ship as a true single-file executable (XAML resources must
; stay next to the binary), so the "portable" flavor is a one-click extractor.

#ifndef AppVersion
  #define AppVersion "1.2.0"
#endif
#ifndef SourcePath
  #define SourcePath "..\build"
#endif
#ifndef DistPath
  #define DistPath "..\dist"
#endif

#define AppName "Clippi"
#define AppExeName "Clippi.exe"
#define AppGuid "{{7A1F0D3C-52B8-4E2A-9C6D-8B4E5F1A2C3D}"

[Setup]
AppId={#AppGuid}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher=Clippi
; Per-user installs keep novices away from UAC prompts.
PrivilegesRequired=lowest
WizardStyle=modern
Compression=lzma2/max
SolidCompression=yes
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir={#DistPath}
LicenseFile=..\LICENSE
DisableWelcomePage=no

#ifdef PORTABLE
DefaultDirName={src}\Clippi
Uninstallable=no
; The portable build just unpacks; skip pages that imply a system install.
DisableProgramGroupPage=yes
OutputBaseFilename=Clippi-Portable-x64
#else
DefaultDirName={autopf}\Clippi
DefaultGroupName={#AppName}
UninstallDisplayName={#AppName}
OutputBaseFilename=Clippi-Setup-x64
#endif

[Languages]
Name: "chs"; MessagesFile: "ChineseSimplified.isl"
Name: "en";  MessagesFile: "compiler:Default.isl"
Name: "ja";  MessagesFile: "compiler:Languages\Japanese.isl"

[Tasks]
#ifndef PORTABLE
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"
#endif

[Files]
; The publish output already contains ffmpeg\ffmpeg.exe and ffmpeg\ffprobe.exe.
Source: "{#SourcePath}\*"; DestDir: "{app}"; Excludes: "*.pdb"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
#ifndef PORTABLE
Name: "{autoprograms}\{#AppName}\{#AppName}"; Filename: "{app}\{#AppExeName}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExeName}"; Tasks: desktopicon
#endif

[Run]
Filename: "{app}\{#AppExeName}"; Description: "{cm:LaunchProgram,{#AppName}}"; Flags: nowait postinstall skipifsilent
