. "$PSScriptRoot/../tools/Release.Common.ps1"
function Reject($Action) {
    $rejected = $false
    try { & $Action } catch { $rejected = $true }
    if (!$rejected) { throw 'Unsafe release input was accepted' }
}
foreach ($uri in 'http://host.test','https://localhost','https://127.0.0.1','https://a.invalid','https://user:password@host.test','https://host.test/file?secret=x') {
    Reject { Assert-Https $uri }
}
Assert-Https 'https://downloads.host.test/releases'
Reject { Read-ReleaseSettings "$PSScriptRoot/../release/settings.example.json" }
Write-Output 'Release URL and unconfigured-release rejection tests passed'
