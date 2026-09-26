# Scan without executing the JAR. A missing/inactive scanner is NOT a clean result.
param([string]$Artifact = 'download\spoticraft-26.2.jar', [string]$ReportPath = 'build\defender-scan-report.json')
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'security\defender-validation.ps1')
try {
    $path = (Resolve-Path -LiteralPath $Artifact).Path
    $hash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
    Write-Host "Artifact SHA-256: $hash"
    $status = Get-MpComputerStatus
    $preferences = Get-MpPreference
    $issues = @(Get-DefenderValidationIssues $status $preferences)
    if ($issues.Count -gt 0) { throw "Scan environment is insufficient: $($issues -join '; '). No clean verdict." }
    Update-MpSignature
    $status = Get-MpComputerStatus
    Write-Host "Defender engine: $($status.AMEngineVersion); signatures: $($status.AntivirusSignatureVersion); updated: $($status.AntivirusSignatureLastUpdated)"
    $scanner = Get-ChildItem -Path "$env:ProgramData\Microsoft\Windows Defender\Platform\*\MpCmdRun.exe" -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
    $executable = if ($scanner) { $scanner.FullName } else { Join-Path $env:ProgramFiles 'Windows Defender\MpCmdRun.exe' }
    if (-not (Test-Path -LiteralPath $executable)) { throw 'Microsoft Defender scanner is unavailable.' }
    $cloud = & $executable -ValidateMapsConnection 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) { throw "MAPS connectivity could not be verified: $cloud" }
    $exclusion = & $executable -CheckExclusion -Path $path 2>&1 | Out-String
    $exclusionCode = $LASTEXITCODE
    if (-not (Test-DefenderNotExcluded $exclusionCode $exclusion)) { throw "Scan exclusion status is not acceptable: $exclusion" }
    $started = Get-Date
    $scanOutput = & $executable -Scan -ScanType 3 -File $path 2>&1 | Out-String
    $code = $LASTEXITCODE
    [IO.File]::WriteAllText((Join-Path (Get-Location) 'defender-scan.log'), $scanOutput)
    Write-Host $scanOutput
    if (-not (Test-DefenderCompletedScan $code $scanOutput)) { throw 'Scan was skipped, incomplete, failed or unrecognized. No clean verdict.' }
    # MpCmdRun can return zero after successful remediation: check detections too.
    $detected = @(Get-MpThreatDetection | Where-Object {
        $_.InitialDetectionTime -ge $started.AddSeconds(-5) -or
        (($_.Resources -join ' ') -like "*$path*")
    })
    if ($code -ne 0 -or $detected.Count -gt 0 -or -not (Test-Path -LiteralPath $path)) {
        $details = ($detected | Select-Object ThreatID, ActionSuccess, Resources | ConvertTo-Json -Compress -Depth 4)
        throw "Defender scan did not pass. Exit code: $code. Detections: $details"
    }
    if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ne $hash) { throw 'The artifact changed during scanning.' }
    $report = @{
        fileName = [IO.Path]::GetFileName($path); sha256 = $hash.ToLowerInvariant()
        engine = $status.AMEngineVersion; signatures = $status.AntivirusSignatureVersion
        scannedUtc = [DateTime]::UtcNow.ToString('o'); result = 'no-detection-observed-in-completed-ci-scan'
        scanCompleted = $true; protectionVerified = $true; cloudConnectionVerified = $true; exclusionChecked = $true
        runId = $env:GITHUB_RUN_ID
    }
    $fullReport = [IO.Path]::GetFullPath($ReportPath)
    [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($fullReport)) | Out-Null
    [IO.File]::WriteAllText($fullReport, ($report | ConvertTo-Json), (New-Object Text.UTF8Encoding($false)))
    Write-Host "::notice title=Defender scan completed::No detection on this runner for SHA-256 $hash, signatures $($status.AntivirusSignatureVersion). This is not a guarantee of safety on other devices."
} catch {
    $message = ($_ | Out-String).Replace('%', '%25').Replace("`r", '%0D').Replace("`n", '%0A')
    Write-Host "::error title=Defender scan not passed::$message"
    exit 1
}
