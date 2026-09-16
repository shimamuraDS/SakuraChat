param(
    [Parameter(Mandatory)][string]$BuildDirectory,
    [Parameter(Mandatory)][string]$QtBin,
    [Parameter(Mandatory)][string]$MinGWBin,
    [Parameter(Mandatory)][string]$OpenSslBin,
    [Parameter(Mandatory)][string]$RuntimeDll,
    [Parameter(Mandatory)][string]$LicenseDirectory,
    [Parameter(Mandatory)][string]$OutputDirectory
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$project = Split-Path $PSScriptRoot -Parent
$cache = Get-Content -LiteralPath "$BuildDirectory/CMakeCache.txt" -Raw
if ($cache -notmatch '(?m)^SAKURA_DISTRIBUTION:BOOL=ON\r?$' -or
    $cache -notmatch '(?m)^CMAKE_BUILD_TYPE:STRING=Release\r?$' -or
    $cache -notmatch '(?m)^SAKURA_RELEASE_VERSION:STRING=(\d+\.\d+\.\d+)\r?$') {
    throw 'Requires a production distribution Release build with a numeric version.'
}
$versionMatch = [regex]::Match($cache, '(?m)^SAKURA_RELEASE_VERSION:STRING=(\d+\.\d+\.\d+)\r?$')
$version = $versionMatch.Groups[1].Value
if (!(Test-Path -LiteralPath "$LicenseDirectory/libsignal-AGPL.txt")) { throw 'Missing license bundle' }
$name = "SakuraChat-$version-windows-x64-portable"
$stage = Join-Path $OutputDirectory $name
if (Test-Path -LiteralPath $stage) { throw 'Use a fresh output directory' }
$null = New-Item -ItemType Directory -Path $stage
$savedPath = $env:PATH
try {
    $env:PATH = "$QtBin;$MinGWBin;" + $savedPath
    & "$BuildDirectory/tlsconfig_tests.exe"
    if ($LASTEXITCODE -ne 0) { throw 'TLS configuration tests failed' }
    Copy-Item -LiteralPath "$BuildDirectory/appSakuraChat.exe", "$project/crypto/signal-bridge/target/release/sakura_signal_bridge.dll" -Destination $stage
    & "$QtBin/windeployqt.exe" --release --no-translations --no-opengl-sw --no-system-d3d-compiler --skip-plugin-types platforminputcontexts,qmltooling,sqldrivers --qmldir "$project/qml" --compiler-runtime "$stage/appSakuraChat.exe"
    if ($LASTEXITCODE -ne 0) { throw 'Qt deployment failed' }
    # windeployqt may omit this plugin when OpenSSL is supplied after Qt deployment.
    # LAN TLS hosting requires the OpenSSL backend, not just Windows Schannel.
    Copy-Item -LiteralPath "$QtBin/../plugins/tls/qopensslbackend.dll" -Destination "$stage/tls"
    $null = New-Item -ItemType Directory -Path "$stage/sqldrivers"
    Copy-Item -LiteralPath "$QtBin/../plugins/sqldrivers/qsqlite.dll" -Destination "$stage/sqldrivers"
    foreach ($file in 'openssl.exe','libssl-3-x64.dll','libcrypto-3-x64.dll') {
        Copy-Item -LiteralPath (Join-Path $OpenSslBin $file) -Destination $stage
    }
    if ((Split-Path $RuntimeDll -Leaf) -ne 'vcruntime140.dll') { throw 'Expected the redistributable VCRUNTIME140.dll' }
    Copy-Item -LiteralPath $RuntimeDll -Destination $stage
    Copy-Item -LiteralPath $LicenseDirectory -Destination "$stage/licenses" -Recurse
    Copy-Item -LiteralPath "$project/release/PORTABLE_README.txt" -Destination "$stage/README.txt"
    Copy-Item -LiteralPath "$project/release/THIRD_PARTY_NOTICES.txt" -Destination "$stage/THIRD_PARTY_NOTICES.txt"
    $inventory = @(Get-ChildItem -LiteralPath $stage -Recurse -File | ForEach-Object {
        $relative = [IO.Path]::GetRelativePath($stage,$_.FullName)
        if (!$relative.StartsWith('licenses' + [IO.Path]::DirectorySeparatorChar) -and $_.Extension -in '.key','.pfx','.p12','.db','.sqlite','.log','.ini') { throw "Unexpected private or configuration file: $($_.Name)" }
        @{ path=[IO.Path]::GetRelativePath($stage,$_.FullName); sha256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash; bytes=$_.Length }
    })
    $inventory | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath "$OutputDirectory/payload-inventory.json" -Encoding utf8
    Compress-Archive -LiteralPath $stage -DestinationPath "$OutputDirectory/$name.zip" -CompressionLevel Optimal
    Get-FileHash -LiteralPath "$OutputDirectory/$name.zip" -Algorithm SHA256
} finally { $env:PATH = $savedPath }
