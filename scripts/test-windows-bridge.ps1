# Run in Windows PowerShell 5.1, the exact runtime launched by the mod (not pwsh).
$ErrorActionPreference = 'Stop'
try {
    if ($PSVersionTable.PSEdition -ne 'Desktop') { throw 'Run with Windows PowerShell 5.1' }
    . (Join-Path $PSScriptRoot '..\src\main\resources\native\spotify-session.ps1') -LibraryOnly
    function Check($Condition, [string]$Message) {
        if (-not $Condition) { throw "Assertion failed: $Message" }
        Write-Host "PASS: $Message"
    }
    function New-Diagnostics { return ,(New-Object 'System.Collections.Generic.List[object]') }
    function New-Cache { return @{ key = ''; cover = ''; retryAt = [DateTime]::MinValue } }
    Initialize-WinRt
    $null = [Windows.Storage.Streams.InMemoryRandomAccessStream, Windows.Storage.Streams, ContentType=WindowsRuntime]
    $null = [Windows.Storage.Streams.DataWriter, Windows.Storage.Streams, ContentType=WindowsRuntime]
    $null = [Windows.Storage.Streams.RandomAccessStreamReference, Windows.Storage.Streams, ContentType=WindowsRuntime]

    # Real WinRT stream, not a mock: exercises Async reflection, ReadBytes and cleanup.
    $stream = [Windows.Storage.Streams.InMemoryRandomAccessStream]::new()
    $writer = [Windows.Storage.Streams.DataWriter]::new($stream)
    $bytes = [byte[]]@(1, 2, 3, 4, 5)
    $writer.WriteBytes($bytes)
    $stored = Await ($writer.StoreAsync()) ([uint32])
    $null = $writer.DetachStream()
    Close-WinRtObject $writer
    $stream.Seek(0)
    $thumbnail = [Windows.Storage.Streams.RandomAccessStreamReference]::CreateFromStream($stream)
    $expected = [Convert]::ToBase64String($bytes)
    $diagnostics = New-Diagnostics
    $cover = Read-Cover $thumbnail $diagnostics
    Check ($cover -eq $expected) 'Real WinRT thumbnail read returns the expected bytes'
    Check ($diagnostics.Count -eq 0) 'Explicit IDisposable cleanup succeeds on real WinRT objects'

    # Diagnose the OLD code without requiring a Spotify account or GUI session.
    $probeStream = Await ($thumbnail.OpenReadAsync()) ([Windows.Storage.Streams.IRandomAccessStreamWithContentType])
    $probeReader = [Windows.Storage.Streams.DataReader]::new($probeStream)
    try {
        $probeReader.Dispose()
        Write-Host '::notice title=Old cleanup probe::Direct DataReader.Dispose is supported on this runner.'
    } catch {
        $message = $_.Exception.Message.Replace('%', '%25').Replace("`r", '%0D').Replace("`n", '%0A')
        Write-Host "::notice title=Old cleanup probe::Old direct DataReader.Dispose failed: $message"
    } finally {
        try { Close-WinRtObject $probeReader } catch { }
        try { Close-WinRtObject $probeStream } catch { }
    }

    $savedClose = ${function:Close-WinRtObject}
    $script:closeCalls = 0
    function Close-WinRtObject($Value) {
        $script:closeCalls++
        throw 'Simulated WinRT cleanup failure'
    }
    $diagnostics = New-Diagnostics
    $cover = Read-Cover $thumbnail $diagnostics
    Check ($cover -eq $expected) 'Cleanup failure does not discard a successfully read cover'
    Check ($script:closeCalls -eq 2) 'Both resources are closed independently'
    Check ($diagnostics.Count -eq 2) 'Cleanup failures produce separate diagnostics'
    Set-Item Function:Close-WinRtObject $savedClose

    # Snapshot tests replace only the async media call. Production snapshot logic is reused.
    function Read-MediaProperties($Session) {
        if ($Session.FailMetadata) { throw 'Simulated media properties error' }
        return $Session.Properties
    }
    function New-Session {
        $s = [pscustomobject]@{
            SourceAppUserModelId = 'Spotify.exe'; FailMetadata = $false
            FailPlayback = $false; FailTimeline = $false; Playing = $true
            Properties = [pscustomobject]@{ Title = 'Test song'; Artist = 'Artist'; AlbumTitle = 'Album'; Thumbnail = $null }
        }
        $s | Add-Member ScriptMethod GetPlaybackInfo {
            if ($this.FailPlayback) { throw 'Simulated stale session' }
            return [pscustomobject]@{ PlaybackStatus = $(if ($this.Playing) { 'Playing' } else { 'Paused' }) }
        }
        $s | Add-Member ScriptMethod GetTimelineProperties {
            if ($this.FailTimeline) { throw 'Simulated timeline error' }
            return [pscustomobject]@{ StartTime = [TimeSpan]::Zero; EndTime = [TimeSpan]::FromSeconds(180)
                Position = [TimeSpan]::FromSeconds(20); LastUpdatedTime = [DateTimeOffset]::UtcNow.AddSeconds(-2) }
        }
        return $s
    }
    $s = New-Session
    $snapshot = Read-Snapshot $s (New-Cache) (New-Diagnostics)
    Check ($snapshot.available -and $snapshot.title -eq 'Test song') 'Track without artwork remains available'
    Check ($snapshot.duration -eq 180 -and $snapshot.position -ge 22 -and $snapshot.position -lt 25) 'Typed timeline arithmetic interpolates from LastUpdatedTime'
    $s.Playing = $false
    $snapshot = Read-Snapshot $s (New-Cache) (New-Diagnostics)
    Check ($snapshot.position -eq 20 -and -not $snapshot.playing) 'Paused track does not extrapolate'
    $s.FailTimeline = $true
    $snapshot = Read-Snapshot $s (New-Cache) (New-Diagnostics)
    Check ($snapshot.available -and $snapshot.duration -eq 0 -and $snapshot.diagnostics[0].stage -eq 'timeline') 'Broken timeline preserves title and reports its own stage'
    $s.FailPlayback = $true
    $snapshot = Read-Snapshot $s (New-Cache) (New-Diagnostics)
    Check ($snapshot.available -and -not $snapshot.playing) 'Missing playback status preserves track metadata'

    $s = New-Session
    $s.Properties.Thumbnail = $thumbnail
    $script:coverReads = 0
    function Read-Cover($Thumbnail, $Diagnostics) {
        $script:coverReads++
        throw 'Simulated broken thumbnail'
    }
    $cache = New-Cache
    $snapshot = Read-Snapshot $s $cache (New-Diagnostics)
    Check ($snapshot.available -and $snapshot.diagnostics[0].stage -eq 'cover-read') 'Broken thumbnail does not mark Spotify unavailable'
    $null = Read-Snapshot $s $cache (New-Diagnostics)
    Check ($script:coverReads -eq 1) 'Failed cover reads are retried with backoff'
    $s.Properties.Title = 'Next song'
    $null = Read-Snapshot $s $cache (New-Diagnostics)
    Check ($script:coverReads -eq 2) 'Changing track resets artwork retry state'

    $bad = New-Session; $bad.FailPlayback = $true
    $good = New-Session
    $diagnostics = New-Diagnostics
    $selected = Select-SpotifySession @($bad, $good) $diagnostics
    Check ([object]::ReferenceEquals($selected, $good)) 'One stale Spotify session does not hide a healthy playing session'
    Check ($diagnostics[0].stage -eq 'session-select') 'Session selection failure has a diagnostic stage'
    $none = Select-SpotifySession @() (New-Diagnostics)
    Check ($null -eq $none) 'Closed Spotify returns no session'
    $s.FailMetadata = $true
    $failed = $false
    try { $null = Read-Snapshot $s (New-Cache) (New-Diagnostics) } catch { $failed = $true }
    Check $failed 'Essential metadata errors are not silently reported as successful playback'
    $wire = $snapshot | ConvertTo-Json -Compress -Depth 5 | ConvertFrom-Json
    Check ($wire.available -and $wire.diagnostics[0].stage -eq 'cover-read') 'JSON diagnostic protocol round-trips'
    Close-WinRtObject $stream
    Write-Host 'Windows bridge regression tests passed.'
} catch {
    $message = ($_ | Out-String) + $_.ScriptStackTrace
    $message = $message.Replace('%', '%25').Replace("`r", '%0D').Replace("`n", '%0A')
    Write-Host "::error title=Windows bridge regression test::$message"
    exit 1
}
