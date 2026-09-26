# Scan without executing the JAR. A missing/inactive scanner is NOT a clean result.
param([string]$Artifact = 'download\spoticraft-26.2.jar', [string]$ReportPath = 'build\defender-scan-report.json')
$ErrorActionPreference = 'Stop'
try {
    $path = (Resolve-Path -LiteralPath $Artifact).Path
    $hash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
    Write-Host "Artifact SHA-256: $hash"
    $status = Get-MpComputerStatus
    if (-not $status.AMServiceEnabled -or -not $status.AntivirusEnabled) {
        throw 'Defender is not active on this runner. No security verdict is available.'
    }
    Update-MpSignature
    $status = Get-MpComputerStatus
    Write-Host "Defender engine: $($status.AMEngineVersion); signatures: $($status.AntivirusSignatureVersion); updated: $($status.AntivirusSignatureLastUpdated)"
    $scanner = Get-ChildItem -Path "$env:ProgramData\Microsoft\Windows Defender\Platform\*\MpCmdRun.exe" -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
    $executable = if ($scanner) { $scanner.FullName } else { Join-Path $env:ProgramFiles 'Windows Defender\MpCmdRun.exe' }
    if (-not (Test-Path -LiteralPath $executable)) { throw 'Microsoft Defender scanner is unavailable.' }
    $started = Get-Date
    & $executable -Scan -ScanType 3 -File $path 2>&1 | Tee-Object -FilePath defender-scan.log
    $code = $LASTEXITCODE
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
        scannedUtc = [DateTime]::UtcNow.ToString('o'); result = 'no-detection-on-ci-runner'
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
