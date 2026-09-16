Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
function Assert-Https([string]$Value) {
    $uri = $null
    if (![Uri]::TryCreate($Value, [UriKind]::Absolute, [ref]$uri) -or $uri.Scheme -ne 'https' -or
        $uri.IsLoopback -or $uri.UserInfo -or $uri.Query -or $uri.Fragment -or
        $uri.Host -match '\.(invalid|example)$' -or $Value -notmatch '^https://[A-Za-z0-9.-]+(:[0-9]+)?(/[-A-Za-z0-9._~/]*)?$') {
        throw 'A production HTTPS URL without credentials, query or fragment is required.'
    }
}
function Read-ReleaseSettings([string]$Path) {
    $settings = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
    if ($settings.version -notmatch '^\d+\.\d+\.\d+$') { throw 'Invalid release version' }
    foreach ($field in 'gateway','correspondingSourceUrl') { Assert-Https $settings.$field }
    if ($settings.githubRepository -notmatch '^[A-Za-z0-9_-]+/[A-Za-z0-9_.-]+$') { throw 'GitHub repository must be owner/repository' }
    if ($settings.publisher -notmatch '^[A-Za-z0-9 ._-]+$') { throw 'Publisher identity is required' }
    if ($settings.certificateThumbprint -notmatch '^[A-Fa-f0-9]{40}$') { throw 'Code signing certificate thumbprint is required' }
    Assert-Https $settings.timestampUrl
    if (!$settings.licenseReviewComplete) { throw 'Complete the distribution license review first' }
    return $settings
}
function Invoke-Checked([string]$Exe, [string[]]$Arguments) {
    & $Exe @Arguments
    if ($LASTEXITCODE -ne 0) { throw "External tool failed: $Exe (exit $LASTEXITCODE)" }
}
function Assert-Signed([string]$Path, [string]$Thumbprint) {
    $signature = Get-AuthenticodeSignature -LiteralPath $Path
    if ($signature.Status -ne 'Valid' -or $signature.SignerCertificate.Thumbprint -ne $Thumbprint) { throw "Publisher signature verification failed: $Path" }
}
function Sign-ReleaseFile([string]$Path, $Settings, [string]$SignTool) {
    Invoke-Checked $SignTool @('sign','/sha1',$Settings.certificateThumbprint,'/fd','SHA256','/tr',$Settings.timestampUrl,'/td','SHA256',$Path)
    Assert-Signed $Path $Settings.certificateThumbprint
}
