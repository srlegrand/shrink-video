; Inno Setup script for the Windows installer (ShrinkVideo-Setup.exe).
; Build:  iscc /DAppVersion=1.2.3 windows\setup.iss      -> dist\ShrinkVideo-Setup.exe
; Installs for the current user only - no admin rights needed.

#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif

[Setup]
AppId={{6F2C3B1E-8D47-4E55-9C3A-5B0E7A1D2F64}
AppName=Shrink Video
AppVersion={#AppVersion}
AppPublisher=Simon Legrand
AppPublisherURL=https://srlegrand.github.io/shrink-video/
AppSupportURL=https://github.com/srlegrand/shrink-video/issues
DefaultDirName={localappdata}\ShrinkVideo
DisableDirPage=yes
DisableProgramGroupPage=yes
DisableReadyPage=yes
PrivilegesRequired=lowest
OutputDir=..\dist
OutputBaseFilename=ShrinkVideo-Setup
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
UninstallDisplayName=Shrink Video

[Tasks]
Name: "ffmpeg"; Description: "Download and install ffmpeg with winget (required - it was not found on this PC)"; Check: not HasFfmpeg

[Files]
Source: "shrink-video.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "install.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\LICENSE"; DestDir: "{app}"; DestName: "LICENSE.txt"; Flags: ignoreversion

[Run]
Filename: "powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\install.ps1"" -NoPrompt"; StatusMsg: "Adding the right-click menu..."; Flags: runhidden
Filename: "{cmd}"; Parameters: "/c winget install --id Gyan.FFmpeg -e --accept-source-agreements --accept-package-agreements"; StatusMsg: "Installing ffmpeg (this can take a few minutes)..."; Tasks: ffmpeg

[UninstallRun]
Filename: "powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\install.ps1"" -Uninstall -KeepFiles"; Flags: runhidden; RunOnceId: "RemoveMenu"

[UninstallDelete]
Type: filesandordirs; Name: "{app}"

[Messages]
FinishedLabel=Setup has finished. Right-click any video file and choose "Shrink video".%n%nOn Windows 11 it is under "Show more options" (or Shift + right-click).

[Code]
function HasFfmpeg: Boolean;
begin
  Result := FileSearch('ffmpeg.exe', GetEnv('PATH')) <> '';
end;
