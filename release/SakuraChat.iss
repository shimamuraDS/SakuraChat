#ifndef StageDir
  #error StageDir is required
#endif
#ifndef ReleaseVersion
  #error ReleaseVersion is required
#endif
#ifndef PublisherName
  #error PublisherName is required
#endif
[Setup]
AppId={{87386D5D-6478-4397-97A5-AC28158C77F6}
AppName=SakuraChat
AppVersion={#ReleaseVersion}
AppPublisher={#PublisherName}
DefaultDirName={localappdata}\Programs\SakuraChat
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir={#OutputDir}
OutputBaseFilename=SakuraChat-{#ReleaseVersion}-windows-x64
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
CloseApplications=yes
RestartApplications=no
AppMutex=SakuraChat.Release.Running
SignTool=release
SignedUninstaller=yes
UninstallDisplayIcon={app}\appSakuraChat.exe
[Files]
Source: "{#StageDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
[Icons]
Name: "{autoprograms}\SakuraChat"; Filename: "{app}\appSakuraChat.exe"
[Code]
function PrepareToInstall(var NeedsRestart: Boolean): String;
var Existing: String;
begin
  Result := '';
  if GetVersionNumbersString(ExpandConstant('{app}\appSakuraChat.exe'), Existing) then
    if ComparePackedVersion(StrToVersion(Existing), StrToVersion('{#ReleaseVersion}')) > 0 then
    begin
      Result := 'A newer version is already installed. Downgrades are not supported.';
    end;
end;
