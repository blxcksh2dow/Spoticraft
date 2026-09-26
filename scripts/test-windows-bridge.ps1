# Run on Windows PowerShell 5.1, the exact runtime launched by the mod, not pwsh.
$ErrorActionPreference = 'Stop'
try {
    if ($PSVersionTable.PSEdition -ne 'Desktop') { throw 'Run with Windows PowerShell 5.1' }
    . (Join-Path $PSScriptRoot '..\src\main\resources\native\spotify-session.ps1') -LibraryOnly
    Initialize-SpoticraftBridge ([IO.File]::ReadAllText((Join-Path $PSScriptRoot 'WindowsBridgeTests.cs')))
    $summary = [Spoticraft.Tests.WindowsBridgeTests]::Run()
    Write-Host "::notice title=Windows bridge tests::$summary"
    # Check JSON serialization of the exact DTOs seen by Java (including numeric fields).
    $sample = New-Object Spoticraft.Native.Snapshot
    $sample.available = $true; $sample.title = 'Song'; $sample.duration = 180
    $sample.diagnostics.Add((New-Object Spoticraft.Native.Diagnostic 'cover-read', (New-Object System.Exception 'Test error')))
    $wire = $sample | ConvertTo-Json -Compress -Depth 5 | ConvertFrom-Json
    if (-not $wire.available -or $wire.title -ne 'Song' -or $wire.duration -ne 180 -or $wire.diagnostics[0].stage -ne 'cover-read') {
        throw 'JSON protocol round-trip failed'
    }
    Write-Host '::notice title=Windows bridge JSON::DTO serialization test passed.'
} catch {
    $message = ($_ | Out-String) + $_.ScriptStackTrace
    $message = $message.Replace('%', '%25').Replace("`r", '%0D').Replace("`n", '%0A')
    Write-Host "::error title=Windows bridge regression test::$message"
    exit 1
}
