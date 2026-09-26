# ONLY for the disposable CI investigation VM. Strengthens protection; never run on user PCs.
$ErrorActionPreference = 'Stop'
try {
    if ($env:GITHUB_ACTIONS -ne 'true') { throw 'Refusing: this setup is restricted to the disposable GitHub Actions runner.' }
    # Remove only the disposable runner's preset exclusions, strengthening its protection.
    # No signatures are removed and no quarantined threats are ever restored.
    $prefs = Get-MpPreference
    foreach ($kind in @('ExclusionPath', 'ExclusionExtension', 'ExclusionProcess')) {
        $count = 0
        foreach ($value in @($prefs.$kind)) {
            if ([string]::IsNullOrWhiteSpace([string]$value)) { continue }
            $arguments = @{}; $arguments[$kind] = $value
            Remove-MpPreference @arguments
            $count++
        }
        Write-Host "::notice title=CI protection::Removed $count preset $kind entries from disposable runner only. No exclusions added."
    }
    Set-MpPreference -DisableArchiveScanning $false -DisableRealtimeMonitoring $false `
        -DisableIOAVProtection $false -DisableBehaviorMonitoring $false `
        -DisableScriptScanning $false -DisableBlockAtFirstSeen $false `
        -MAPSReporting 2 -SubmitSamplesConsent 1
    . (Join-Path $PSScriptRoot 'defender-validation.ps1')
    $issues = @(Get-DefenderValidationIssues (Get-MpComputerStatus) (Get-MpPreference))
    if ($issues.Count -gt 0) {
        Write-Host "::warning title=CI protection::Settings requested; activation not yet confirmed: $($issues -join '; '). The investigation must recheck."
    }
    Write-Host '::notice title=CI protection::Archive, real-time, IOAV and cloud protection requested on disposable runner; actual state is rechecked by investigation. Safe-sample submission policy enabled; no sample is executed.'
} catch {
    $message = ($_ | Out-String).Replace('%', '%25').Replace("`r", '%0D').Replace("`n", '%0A')
    Write-Host "::warning title=CI protection not confirmed::$message"
    exit 1
}
