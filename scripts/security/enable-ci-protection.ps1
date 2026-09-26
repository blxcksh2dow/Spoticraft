# ONLY for the disposable CI investigation VM. Strengthens protection; never run on user PCs.
$ErrorActionPreference = 'Stop'
try {
    if ($env:GITHUB_ACTIONS -ne 'true') { throw 'Refusing: this setup is restricted to the disposable GitHub Actions runner.' }
    # No exclusions are added/removed. No signatures are removed, no threats restored.
    Set-MpPreference -DisableArchiveScanning $false -DisableRealtimeMonitoring $false `
        -DisableIOAVProtection $false -DisableBehaviorMonitoring $false `
        -DisableScriptScanning $false -DisableBlockAtFirstSeen $false `
        -MAPSReporting 2 -SubmitSamplesConsent 1
    . (Join-Path $PSScriptRoot 'defender-validation.ps1')
    $issues = @(Get-DefenderValidationIssues (Get-MpComputerStatus) (Get-MpPreference))
    if ($issues.Count -gt 0) { throw "Requested protection could not be verified: $($issues -join '; ')" }
    Write-Host '::notice title=CI protection::Archive, real-time, IOAV and cloud protection enabled on disposable runner. Safe-sample submission policy enabled; no sample is executed.'
} catch {
    $message = ($_ | Out-String).Replace('%', '%25').Replace("`r", '%0D').Replace("`n", '%0A')
    Write-Host "::warning title=CI protection not confirmed::$message"
    exit 1
}
