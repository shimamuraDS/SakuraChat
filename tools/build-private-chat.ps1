param(
    [Parameter(Mandatory = $true)][string]$BuildDirectory,
    [Parameter(Mandatory = $true)][string]$QtBin,
    [string]$Cargo = 'cargo',
    [string]$CMake = 'cmake'
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$manifest = Join-Path $projectRoot 'crypto/signal-bridge/Cargo.toml'
$env:PATH = $QtBin + [IO.Path]::PathSeparator + $env:PATH
& $Cargo test --locked --manifest-path $manifest
if ($LASTEXITCODE -ne 0) { throw 'Signal protocol tests failed' }
& $Cargo build --locked --manifest-path $manifest
if ($LASTEXITCODE -ne 0) { throw 'Signal bridge build failed' }
& $CMake --build $BuildDirectory --target appSakuraChat privatechatstore_tests signalbridge_tests privatechattransport_tests privatechatengine_tests privatechatcontroller_tests -j 2
if ($LASTEXITCODE -ne 0) { throw 'C++ private-chat build failed' }
$library = Join-Path $projectRoot 'crypto/signal-bridge/target/debug/sakura_signal_bridge.dll'
& $CMake -E copy_if_different $library $BuildDirectory
if ($LASTEXITCODE -ne 0) { throw 'Bridge deployment failed' }
& (Join-Path $BuildDirectory 'privatechatstore_tests.exe')
if ($LASTEXITCODE -ne 0) { throw 'Private state tests failed' }
& (Join-Path $BuildDirectory 'signalbridge_tests.exe')
if ($LASTEXITCODE -ne 0) { throw 'C++ / Rust bridge tests failed' }
& (Join-Path $BuildDirectory 'privatechattransport_tests.exe')
if ($LASTEXITCODE -ne 0) { throw 'Private transport tests failed' }
& (Join-Path $BuildDirectory 'privatechatengine_tests.exe')
if ($LASTEXITCODE -ne 0) { throw 'Private engine tests failed' }
& (Join-Path $BuildDirectory 'privatechatcontroller_tests.exe')
if ($LASTEXITCODE -ne 0) { throw 'Private controller tests failed' }
