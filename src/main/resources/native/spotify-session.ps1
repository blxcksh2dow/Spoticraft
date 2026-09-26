# Windows PowerShell 5.1, Windows 10 1809+. Read-only GSMTC bridge.
# LibraryOnly allows the SAME functions to be exercised by Windows regression tests.
param([switch]$LibraryOnly)
$ErrorActionPreference = 'Stop'

function Initialize-WinRt {
    Add-Type -AssemblyName System.Runtime.WindowsRuntime
    $null = [Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager, Windows.Media.Control, ContentType=WindowsRuntime]
    $null = [Windows.Media.Control.GlobalSystemMediaTransportControlsSessionMediaProperties, Windows.Media.Control, ContentType=WindowsRuntime]
    $null = [Windows.Storage.Streams.IRandomAccessStreamWithContentType, Windows.Storage.Streams, ContentType=WindowsRuntime]
    $null = [Windows.Storage.Streams.DataReader, Windows.Storage.Streams, ContentType=WindowsRuntime]
    $script:asTask = [System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
        $_.Name -eq 'AsTask' -and $_.IsGenericMethod -and $_.GetParameters().Count -eq 1 -and
        $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1'
    } | Select-Object -First 1
}
function Await($operation, [Type]$type) {
    $task = $script:asTask.MakeGenericMethod($type).Invoke($null, @($operation))
    if (-not $task.Wait(5000)) { throw 'WinRT timeout' }
    return $task.Result
}
function Get-Diagnostic([string]$Stage, $Failure) {
    # No track metadata or cover data in diagnostics.
    $exception = $Failure.Exception.GetBaseException()
    return @{ stage = $Stage; type = $exception.GetType().FullName
        hresult = $exception.HResult; message = $exception.Message }
}
function Close-WinRtObject($Value) {
    if ($null -ne $Value) {
        # WinRT IClosable is projected as an explicit IDisposable implementation.
        # Calling .Dispose() directly on a projected COM object can fail in PS 5.1.
        ([System.IDisposable]$Value).Dispose()
    }
}
function Read-Cover($Thumbnail, $Diagnostics) {
    $stream = $null; $reader = $null
    try {
        $stream = Await ($Thumbnail.OpenReadAsync()) ([Windows.Storage.Streams.IRandomAccessStreamWithContentType])
        if ($stream.Size -le 0 -or $stream.Size -gt 2097152) { return '' }
        $reader = [Windows.Storage.Streams.DataReader]::new($stream)
        $loaded = Await ($reader.LoadAsync([uint32]$stream.Size)) ([uint32])
        $bytes = New-Object byte[] $loaded
        $reader.ReadBytes($bytes)
        return [Convert]::ToBase64String($bytes)
    } finally {
        # Cleanup must NEVER replace a valid song with "session unavailable".
        # Close both resources independently, even if the first close throws.
        foreach ($resource in @($reader, $stream)) {
            try { Close-WinRtObject $resource }
            catch { $Diagnostics.Add((Get-Diagnostic 'cover-close' $_)) }
        }
    }
}
function Read-MediaProperties($Session) {
    return Await ($Session.TryGetMediaPropertiesAsync()) ([Windows.Media.Control.GlobalSystemMediaTransportControlsSessionMediaProperties])
}
function Select-SpotifySession($Sessions, $Diagnostics) {
    $fallback = $null
    foreach ($candidate in $Sessions) {
        try {
            if ($candidate.SourceAppUserModelId -notmatch '(?i)spotify') { continue }
            if ($null -eq $fallback) { $fallback = $candidate }
            $info = $candidate.GetPlaybackInfo()
            if ($null -ne $info -and [string]$info.PlaybackStatus -eq 'Playing') { return $candidate }
        } catch { $Diagnostics.Add((Get-Diagnostic 'session-select' $_)) }
    }
    return $fallback
}
function Read-Snapshot($Session, $Cache, $Diagnostics) {
    $props = Read-MediaProperties $Session
    if ($null -eq $props) { throw 'Windows returned no media properties' }
    $playing = $false
    try {
        $info = $Session.GetPlaybackInfo()
        $playing = $null -ne $info -and [string]$info.PlaybackStatus -eq 'Playing'
    } catch { $Diagnostics.Add((Get-Diagnostic 'playback' $_)) }
    $duration = 0.0; $position = 0.0
    try {
        $timeline = $Session.GetTimelineProperties()
        if ($null -ne $timeline) {
            # Explicit .NET types avoid PowerShell COM projection/overload ambiguity.
            $start = [TimeSpan]$timeline.StartTime
            $end = [TimeSpan]$timeline.EndTime
            $at = [TimeSpan]$timeline.Position
            $duration = [Math]::Max(0.0, $end.Subtract($start).TotalSeconds)
            $position = $at.Subtract($start).TotalSeconds
            if ($playing -and $null -ne $timeline.LastUpdatedTime) {
                $updated = [DateTimeOffset]$timeline.LastUpdatedTime
                if ($updated.Year -gt 2000) {
                    $position += [Math]::Max(0.0, [DateTimeOffset]::UtcNow.Subtract($updated).TotalSeconds)
                }
            }
            $position = [Math]::Max(0.0, [Math]::Min($duration, $position))
        }
    } catch {
        $duration = 0.0; $position = 0.0
        $Diagnostics.Add((Get-Diagnostic 'timeline' $_))
    }
    $key = "$($props.Title)`0$($props.Artist)`0$($props.AlbumTitle)"
    if ($key -ne $Cache.key) {
        $Cache.key = $key; $Cache.cover = ''; $Cache.retryAt = [DateTime]::MinValue
    }
    if (-not $Cache.cover -and [DateTime]::UtcNow -ge $Cache.retryAt) {
        $Cache.retryAt = [DateTime]::UtcNow.AddSeconds(10)
        try {
            if ($null -ne $props.Thumbnail) { $Cache.cover = Read-Cover $props.Thumbnail $Diagnostics }
        } catch { $Diagnostics.Add((Get-Diagnostic 'cover-read' $_)) }
    }
    return @{
        available = -not [string]::IsNullOrWhiteSpace($props.Title)
        title = [string]$props.Title; artist = [string]$props.Artist; album = [string]$props.AlbumTitle
        duration = $duration; position = $position; playing = $playing; cover = [string]$Cache.cover
        status = 'Nessun brano disponibile'; diagnostics = @($Diagnostics.ToArray())
    }
}
function Emit($value) {
    [Console]::WriteLine(($value | ConvertTo-Json -Compress -Depth 5))
    [Console]::Out.Flush()
}

if ($LibraryOnly) { return }
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)
try {
    Initialize-WinRt
    $manager = Await ([Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager]::RequestAsync()) ([Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager])
    $cache = @{ key = ''; cover = ''; retryAt = [DateTime]::MinValue }
    while ($true) {
        $diagnostics = New-Object 'System.Collections.Generic.List[object]'
        $stage = 'session-list'
        try {
            $session = Select-SpotifySession ($manager.GetSessions()) $diagnostics
            if ($null -eq $session) {
                $cache.key = ''; $cache.cover = ''
                Emit @{ available = $false; status = 'Apri Spotify e riproduci un brano'; diagnostics = @($diagnostics.ToArray()) }
            } else {
                $stage = 'media-properties'
                Emit (Read-Snapshot $session $cache $diagnostics)
            }
        } catch {
            $diagnostics.Add((Get-Diagnostic $stage $_))
            Emit @{ available = $false; status = "Spotify: errore $stage (vedi latest.log)"; diagnostics = @($diagnostics.ToArray()) }
        }
        Start-Sleep -Milliseconds 1000
    }
} catch {
    Emit @{ available = $false; status = 'API multimediali Windows non disponibili'
        diagnostics = @((Get-Diagnostic 'initialization' $_)) }
    exit 1
}
