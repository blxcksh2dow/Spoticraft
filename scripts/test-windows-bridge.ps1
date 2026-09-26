# Verify the actual packaged helper starts and returns JSON, without PowerShell at runtime.
$ErrorActionPreference = 'Stop'
try {
    $exe = Join-Path (Split-Path $PSScriptRoot -Parent) 'build\generated\bridge-resources\native\Spoticraft.Bridge.exe'
    $start = New-Object Diagnostics.ProcessStartInfo
    $start.FileName = $exe
    $start.Arguments = '--once'
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $process = [Diagnostics.Process]::Start($start)
    $stdout = $process.StandardOutput.ReadToEndAsync()
    $stderr = $process.StandardError.ReadToEndAsync()
    if (-not $process.WaitForExit(20000)) { $process.Kill(); throw 'Bridge process timed out.' }
    $line = $stdout.GetAwaiter().GetResult()
    $errorText = $stderr.GetAwaiter().GetResult()
    if ($process.ExitCode -ne 0) { throw "Bridge failed: $errorText $line" }
    $snapshot = $line | ConvertFrom-Json
    if ($null -eq $snapshot.available -or $null -eq $snapshot.status -or $null -eq $snapshot.diagnostics) {
        throw 'Bridge stdout did not contain the expected JSON DTO.'
    }
    if ($snapshot.diagnostics.Count -gt 0) {
        throw "Native session smoke test failed: $($snapshot.diagnostics | ConvertTo-Json -Compress)"
    }
    Write-Host '::notice title=Native bridge smoke test::Precompiled executable starts and reads Windows sessions, returning valid JSON. No PowerShell child or runtime compilation.'
} catch {
    $message = ($_ | Out-String).Replace('%', '%25').Replace("`r", '%0D').Replace("`n", '%0A')
    Write-Host "::error title=Native bridge smoke test failed::$message"
    exit 1
} finally {
    if ($null -ne $process) { $process.Dispose() }
}
