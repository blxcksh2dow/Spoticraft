# Pure validation helpers. They do not alter protection settings or run a sample.
function Get-DefenderValidationIssues($Status, $Preferences) {
    $issues = New-Object 'System.Collections.Generic.List[string]'
    foreach ($name in @('AMServiceEnabled','AntivirusEnabled','RealTimeProtectionEnabled','IoavProtectionEnabled','BehaviorMonitorEnabled')) {
        if ($Status.$name -ne $true) { $issues.Add("$name is not confirmed enabled") }
    }
    foreach ($name in @('DisableArchiveScanning','DisableRealtimeMonitoring','DisableIOAVProtection','DisableBlockAtFirstSeen')) {
        if ($null -eq $Preferences.$name -or $Preferences.$name -ne $false) { $issues.Add("$name is not confirmed false") }
    }
    if ($null -eq $Preferences.MAPSReporting -or [int]$Preferences.MAPSReporting -eq 0) { $issues.Add('MAPS cloud protection is not enabled') }
    if ($Status.AMRunningMode -ne 'Normal') { $issues.Add('Defender is not in Normal mode') }
    return $issues.ToArray()
}
function Test-DefenderCompletedScan([int]$ExitCode, [string]$Output) {
    # The English-language CI runner can return 0 after skipping a file.
    # Unknown/localized output is inconclusive, never a passing scan.
    return ($ExitCode -eq 0 -and $Output -match '(?im)Scan (finished|completed)\.' -and $Output -match '(?i)found no threats' -and
        $Output -notmatch '(?i)skipp|exclud|cancel|abort|interrupt|fail|error')
}
function Test-DefenderNotExcluded([int]$ExitCode, [string]$Output) {
    # MpCmdRun -CheckExclusion returns 1 for a non-excluded path.
    # Require the explicit text as well, to distinguish it from other errors.
    return ($ExitCode -eq 1 -and $Output -match '(?i)not excluded' -and $Output -notmatch '(?i)failed|error')
}
