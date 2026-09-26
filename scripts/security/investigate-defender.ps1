# CI-only investigation. Does NOT execute the JAR/helper or change Defender settings.
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'defender-validation.ps1')
$script:incomplete = $false
$root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$results = Join-Path $root 'security-results'
New-Item -ItemType Directory -Force -Path $results | Out-Null
$expected = '3f4e6d149184a01bde57c5b3e1026009bf886659099addffb0425b5fddd63bb4'
$url = 'https://raw.githubusercontent.com/blxcksh2dow/Spoticraft/71b69f0f7fc3610c6dac2662cbfc25bb869a4811/download/spoticraft-26.2.jar'
$report = [ordered]@{
    runId = $env:GITHUB_RUN_ID; sourceCommit = $env:GITHUB_SHA
    startedUtc = [DateTime]::UtcNow.ToString('o'); expectedSha256 = $expected
    noSampleExecution = $true; ciProtectionSetupRequested = ($env:SPOTICRAFT_CI_PROTECTION_SETUP -eq 'true')
    noUserDeviceChanges = $true
    attachmentApiIsNotActualBrowser = $true
    outcome = 'incomplete'; steps = @(); limitations = @(
        'Fresh Windows CI runner, not the affected device.',
        'IAttachmentExecute Save requests Windows attachment validation; it is not a Chrome/Edge download session.',
        'No detection here cannot establish a false positive on another machine.'
    )
}
function Record([string]$Stage, $Data) {
    $item = [ordered]@{ stage = $Stage; data = $Data }
    $report.steps += $item
    $message = ($item | ConvertTo-Json -Depth 8 -Compress).Replace('%', '%25').Replace("`r", '%0D').Replace("`n", '%0A')
    Write-Host "::notice title=Security investigation::$message"
}
function Scan([string]$Path, [string]$Label) {
    $before = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($before -ne $expected) { throw 'Artifact hash mismatch; refusing to test a different file.' }
    $excludedOutput = & $script:scanner -CheckExclusion -Path $Path 2>&1 | Out-String
    $exclusionCode = $LASTEXITCODE
    $notExcluded = Test-DefenderNotExcluded $exclusionCode $excludedOutput
    Record "$Label-exclusion-check" @{ exitCode = $exclusionCode; output = $excludedOutput.Trim(); explicitlyNotExcluded = $notExcluded }
    if (-not $notExcluded) { $script:incomplete = $true }
    $output = & $script:scanner -Scan -ScanType 3 -File $Path 2>&1 | Out-String
    $code = $LASTEXITCODE
    $completed = Test-DefenderCompletedScan $code $output
    if (-not $completed) { $script:incomplete = $true }
    [IO.File]::WriteAllText((Join-Path $results "$Label-scan.log"), $output)
    $exists = Test-Path -LiteralPath $Path
    $after = if ($exists) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() } else { $null }
    Record $Label @{ scanCompleted = $completed; exitCode = $code; fileStillExists = $exists; sha256Before = $before; sha256After = $after; output = $output.Trim() }
    if ($code -ne 0 -or -not $exists -or $after -ne $before) {
        throw "Scanner changed/removed the sample or returned an error ($Label). No retry or restoration."
    }
}
function Read-Environment {
    $state = Get-MpComputerStatus
    $preferences = Get-MpPreference
    $os = Get-CimInstance Win32_OperatingSystem
    $properties = @{}
    # Deliberately omit exclusions, user paths, device identifiers and credentials.
    foreach ($name in @('AMRunningMode','AMServiceEnabled','AntivirusEnabled','RealTimeProtectionEnabled',
        'IoavProtectionEnabled','BehaviorMonitorEnabled','OnAccessProtectionEnabled','IsTamperProtected',
        'AMProductVersion','AMEngineVersion','AntivirusSignatureVersion','AntivirusSignatureLastUpdated')) {
        $properties[$name] = $state.$name
    }
    foreach ($name in @('MAPSReporting','SubmitSamplesConsent','DisableBlockAtFirstSeen','DisableIOAVProtection',
        'DisableRealtimeMonitoring','DisableArchiveScanning','CloudBlockLevel','CloudExtendedTimeout','PUAProtection')) {
        $properties[$name] = $preferences.$name
    }
    $properties['OS'] = $os.Caption
    $properties['OSVersion'] = $os.Version
    $properties['OSBuild'] = $os.BuildNumber
    $issues = @(Get-DefenderValidationIssues $state $preferences)
    $properties['validationIssues'] = $issues
    if ($issues.Count -gt 0) { $script:incomplete = $true }
    Record 'defender-environment' $properties
    if (-not $state.AMServiceEnabled -or -not $state.AntivirusEnabled) { throw 'Defender unavailable; no scan verdict is possible.' }
}
try {
    Read-Environment
    Update-MpSignature
    Read-Environment
    $platform = Get-ChildItem "$env:ProgramData\Microsoft\Windows Defender\Platform\*\MpCmdRun.exe" |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
    $script:scanner = if ($platform) { $platform.FullName } else { Join-Path $env:ProgramFiles 'Windows Defender\MpCmdRun.exe' }
    if (-not (Test-Path $script:scanner)) { throw 'Defender command-line scanner is missing.' }
    $cloudText = & $script:scanner -ValidateMapsConnection 2>&1 | Out-String
    $cloudCode = $LASTEXITCODE
    Record 'maps-connectivity' @{ exitCode = $cloudCode; output = $cloudText.Trim() }
    if ($cloudCode -ne 0) { $script:incomplete = $true }
    $local = Join-Path $root 'download\spoticraft-26.2.jar'
    Scan $local 'repository-copy-static-scan'

    $folder = Join-Path ([Environment]::GetFolderPath('UserProfile')) 'Downloads\SpoticraftSecurityInvestigation'
    New-Item -ItemType Directory -Force -Path $folder | Out-Null
    $download = Join-Path $folder 'spoticraft-26.2 (1).jar'
    # One request for the EXACT published bytes. If protection blocks it, do not retry.
    Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $download -TimeoutSec 120
    $hash = (Get-FileHash -LiteralPath $download -Algorithm SHA256).Hash.ToLowerInvariant()
    Record 'exact-public-download' @{ url = $url; sha256 = $hash; matchesRepository = ($hash -eq $expected) }
    if ($hash -ne $expected) { throw 'Downloaded sample differs from the reported published artifact.' }
    Add-Type -Path (Join-Path $PSScriptRoot 'AttachmentCheck.cs')
    $hr = [Spoticraft.SecurityDiagnostics.AttachmentCheck]::SaveOnly($download, $url)
    $zone = try { ((Get-Content -LiteralPath $download -Stream Zone.Identifier -ErrorAction Stop) -join "`n").Replace([string][char]0, '') } catch { 'not present or not readable' }
    Record 'windows-attachment-save' @{ hresult = $hr; fileStillExists = (Test-Path -LiteralPath $download); zoneIdentifier = $zone }
    if ($hr -ne '0x00000000' -or -not (Test-Path -LiteralPath $download)) {
        throw 'Attachment validation did not succeed; no bypass, execution or restoration attempted.'
    }
    Scan $download 'download-after-attachment-validation'
    $report.outcome = if ($script:incomplete) { 'inconclusive-protection-or-scan-not-verified' } else { 'no-detection-observed-in-completed-tests-not-a-safety-verdict' }
} catch {
    $report.outcome = 'blocked-or-inconclusive-review-steps'
    Record 'investigation-error' @{ type = $_.Exception.GetType().FullName; message = $_.Exception.Message }
} finally {
    try {
        $start = [DateTime]::Parse($report.startedUtc).ToUniversalTime()
        $threats = @(Get-MpThreatDetection | Where-Object { $_.InitialDetectionTime.ToUniversalTime() -ge $start.AddSeconds(-5) -or (($_.Resources -join ' ') -match '(?i)spoticraft-26\.2') })
        $known = @(Get-MpThreat)
        $details = @($threats | ForEach-Object {
            $threat = $_
            @{ id = $threat.ThreatID; name = ($known | Where-Object { $_.ThreatID -eq $threat.ThreatID } | Select-Object -First 1).ThreatName
               initialDetectionTime = $threat.InitialDetectionTime; actionSuccess = $threat.ActionSuccess
               # Include leaf names only, not machine-specific paths.
               affectedFiles = @($threat.Resources | ForEach-Object { Split-Path ([string]$_) -Leaf }) }
        })
        Record 'defender-detections-during-test' $details
        if ($details.Count -gt 0) { $report.outcome = 'detection-observed-review-report' }
    } catch { Record 'detection-history-unavailable' $_.Exception.Message; $report.outcome = 'incomplete-detection-history' }
    $report.finishedUtc = [DateTime]::UtcNow.ToString('o')
    Record 'summary' @{ outcome = $report.outcome; jarHash = $expected; noSampleExecution = $true }
    [IO.File]::WriteAllText((Join-Path $results 'investigation.json'), ($report | ConvertTo-Json -Depth 12), (New-Object Text.UTF8Encoding($false)))
}
# This is an investigation, NOT a release gate. A completed job never approves the JAR.
