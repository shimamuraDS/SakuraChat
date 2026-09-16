param(
    [Parameter(Mandatory)][string]$SettingsPath,
    [Parameter(Mandatory)][string]$QtRoot,
    [Parameter(Mandatory)][string]$MinGWBin,
    [Parameter(Mandatory)][string]$DependencyDirectory,
    [Parameter(Mandatory)][string]$LicenseDirectory,
    [string]$CMake='cmake', [string]$Cargo='cargo', [string]$SignTool='signtool', [string]$ISCC='ISCC'
)
. "$PSScriptRoot/Release.Common.ps1"
$settings = Read-ReleaseSettings $SettingsPath
$project = Split-Path $PSScriptRoot -Parent
$dependencies = (Resolve-Path -LiteralPath $DependencyDirectory).Path
$licenses = (Resolve-Path -LiteralPath $LicenseDirectory).Path
if (!(Test-Path -LiteralPath "$licenses/THIRD_PARTY_NOTICES.txt")) { throw 'Reviewed THIRD_PARTY_NOTICES.txt is required' }
$required = @('openssl.exe')
$names = @{}
foreach ($entry in $settings.dependencyFiles) {
    if ($entry.name -notmatch '^[A-Za-z0-9_.-]+\.(dll|exe)$' -or $names.ContainsKey($entry.name) -or $entry.sha256 -notmatch '^[A-Fa-f0-9]{64}$') { throw 'Invalid or duplicate dependency entry' }
    $names[$entry.name] = $true
    if ((Get-FileHash -LiteralPath (Join-Path $dependencies $entry.name) -Algorithm SHA256).Hash -ne $entry.sha256) { throw "Dependency hash mismatch: $($entry.name)" }
}
foreach ($name in $required) { if (!$names.ContainsKey($name)) { throw "Missing pinned dependency: $name" } }
# A fresh unique tree prevents development files or old package contents leaking into releases.
$job = Join-Path $project ('release-output/' + $settings.version + '-' + [Guid]::NewGuid().ToString('N'))
$build = Join-Path $job 'build'; $stage = Join-Path $job 'payload'; $artifacts = Join-Path $job 'artifacts'
New-Item -ItemType Directory -Path $stage,$artifacts -Force | Out-Null
$env:PATH = "$QtRoot/bin;$MinGWBin;" + $env:PATH
Invoke-Checked $CMake @('-S',$project,'-B',$build,'-G','Ninja',"-DCMAKE_PREFIX_PATH=$QtRoot",'-DCMAKE_BUILD_TYPE=Release','-DSAKURA_DISTRIBUTION=ON',
    "-DSAKURA_RELEASE_VERSION=$($settings.version)","-DSAKURA_GATEWAY=$($settings.gateway)",
    "-DSAKURA_GITHUB_REPOSITORY=$($settings.githubRepository)","-DSAKURA_PUBLISHER=$($settings.publisher)")
$manifest = Join-Path $project 'crypto/signal-bridge/Cargo.toml'
Invoke-Checked $Cargo @('test','--release','--locked','--manifest-path',$manifest)
Invoke-Checked $Cargo @('build','--release','--locked','--manifest-path',$manifest)
Invoke-Checked $CMake @('--build',$build,'--target','appSakuraChat','updatecontroller_tests','messagelistmodel_tests','chatview_tests','privatechatengine_tests','privatechatcontroller_tests','-j','2')
Copy-Item -LiteralPath "$project/crypto/signal-bridge/target/release/sakura_signal_bridge.dll" -Destination $build
foreach ($test in 'updatecontroller_tests','messagelistmodel_tests','chatview_tests','privatechatengine_tests','privatechatcontroller_tests') {
    $env:QT_QPA_PLATFORM = 'offscreen'
    Invoke-Checked "$build/$test.exe" @()
}
Copy-Item -LiteralPath "$build/appSakuraChat.exe","$build/sakura_signal_bridge.dll" -Destination $stage
Invoke-Checked "$QtRoot/bin/windeployqt.exe" @('--release','--qmldir',"$project/qml",'--compiler-runtime',"$stage/appSakuraChat.exe")
foreach ($entry in $settings.dependencyFiles) {
    $destination = Join-Path $stage $entry.name
    if ((Test-Path -LiteralPath $destination) -and (Get-FileHash -LiteralPath $destination).Hash -ne $entry.sha256) { throw "Dependency would overwrite a different staged file: $($entry.name)" }
    Copy-Item -LiteralPath (Join-Path $dependencies $entry.name) -Destination $stage
}
New-Item -ItemType Directory -Path "$stage/licenses" | Out-Null
foreach ($notice in Get-ChildItem -LiteralPath $licenses -File) {
    if ($notice.Extension -notin '.txt','.md' -or ($notice.Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw 'License bundle must contain plain .txt/.md notices only' }
    Copy-Item -LiteralPath $notice.FullName -Destination "$stage/licenses"
}
Sign-ReleaseFile "$stage/appSakuraChat.exe" $settings $SignTool
Sign-ReleaseFile "$stage/sakura_signal_bridge.dll" $settings $SignTool
$inventory = Get-ChildItem -LiteralPath $stage -File -Recurse | ForEach-Object {
    @{ path=[IO.Path]::GetRelativePath($stage,$_.FullName); sha256=(Get-FileHash -LiteralPath $_.FullName).Hash; size=$_.Length }
}
$inventory | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath "$artifacts/payload-inventory.json" -Encoding utf8
$signCommand = '"' + $SignTool + '" sign /sha1 ' + $settings.certificateThumbprint + ' /fd SHA256 /tr ' + $settings.timestampUrl + ' /td SHA256 $f'
Invoke-Checked $ISCC @("/Srelease=$signCommand","/DStageDir=$stage","/DOutputDir=$artifacts","/DReleaseVersion=$($settings.version)","/DPublisherName=$($settings.publisher)","$project/release/SakuraChat.iss")
$installer = Join-Path $artifacts "SakuraChat-$($settings.version)-windows-x64.exe"
Assert-Signed $installer $settings.certificateThumbprint
Write-Output "Signed installer: $installer"
Get-FileHash -LiteralPath $installer -Algorithm SHA256 | Format-List
Write-Output "Publish the installer, checksum, license notices and corresponding source in GitHub Releases with tag v$($settings.version). Nothing has been uploaded."
