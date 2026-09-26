$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'defender-validation.ps1')
function Assert-True($value, $label) { if (-not $value) { throw "Failed: $label" } }
Assert-True (-not (Test-DefenderCompletedScan 0 "Scan starting...`nScan finished.`nScanning example.jar was skipped.")) 'zero exit plus skipped must fail'
Assert-True (-not (Test-DefenderCompletedScan 0 'Scan finished. File excluded.')) 'excluded must fail'
Assert-True (-not (Test-DefenderCompletedScan 2 'Scan finished.')) 'nonzero must fail'
Assert-True (-not (Test-DefenderCompletedScan 0 '')) 'empty output must fail'
Assert-True (Test-DefenderCompletedScan 0 "Scan starting...`nScan finished.") 'completed scan'
Assert-True (Test-DefenderNotExcluded 1 'Path is not excluded.') 'explicit non-exclusion'
Assert-True (-not (Test-DefenderNotExcluded 0 'Path is excluded.')) 'excluded path'
Assert-True (-not (Test-DefenderNotExcluded 1 'Command failed.')) 'error is not non-exclusion'
$status = [pscustomobject]@{ AMServiceEnabled=$true; AntivirusEnabled=$true; RealTimeProtectionEnabled=$true; IoavProtectionEnabled=$true; BehaviorMonitorEnabled=$true; AMRunningMode='Normal' }
$pref = [pscustomobject]@{ DisableArchiveScanning=$false; DisableRealtimeMonitoring=$false; DisableIOAVProtection=$false; DisableBlockAtFirstSeen=$false; MAPSReporting=2 }
Assert-True (@(Get-DefenderValidationIssues $status $pref).Count -eq 0) 'enabled protection'
$pref.DisableArchiveScanning = $true
Assert-True (@(Get-DefenderValidationIssues $status $pref).Count -gt 0) 'disabled archive scanning'
$pref.DisableArchiveScanning = $false; $pref.MAPSReporting = 0
Assert-True (@(Get-DefenderValidationIssues $status $pref).Count -gt 0) 'disabled cloud protection'
Assert-True (@(Get-DefenderValidationIssues ([pscustomobject]@{}) ([pscustomobject]@{})).Count -gt 0) 'unknown status fails closed'
Write-Host '::notice title=Defender validator tests::12 checks passed, including the exact skipped-scan regression.'
