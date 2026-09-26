# Windows PowerShell 5.1, Windows 10 1809+. Read-only GSMTC bridge.
# stdout is a UTF-8 JSON-lines protocol; never evaluates track metadata as code.
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)
Add-Type -AssemblyName System.Runtime.WindowsRuntime
$null = [Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager, Windows.Media.Control, ContentType=WindowsRuntime]
$null = [Windows.Media.Control.GlobalSystemMediaTransportControlsSessionMediaProperties, Windows.Media.Control, ContentType=WindowsRuntime]
$null = [Windows.Storage.Streams.IRandomAccessStreamWithContentType, Windows.Storage.Streams, ContentType=WindowsRuntime]
$null = [Windows.Storage.Streams.DataReader, Windows.Storage.Streams, ContentType=WindowsRuntime]
$asTask = [System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
    $_.Name -eq 'AsTask' -and $_.IsGenericMethod -and $_.GetParameters().Count -eq 1 -and
    $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1'
} | Select-Object -First 1
function Await($operation, [Type]$type) {
    $task = $asTask.MakeGenericMethod($type).Invoke($null, @($operation))
    if (-not $task.Wait(5000)) { throw 'WinRT timeout' }
    return $task.Result
}
function Emit($value) {
    [Console]::WriteLine(($value | ConvertTo-Json -Compress -Depth 4))
    [Console]::Out.Flush()
}
try {
    $manager = Await ([Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager]::RequestAsync()) ([Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager])
    $lastKey = ''
    $cover = ''
    while ($true) {
        try {
            # Spotify desktop and Microsoft Store AUMIDs, not the current browser session.
            $sessions = @($manager.GetSessions() | Where-Object { $_.SourceAppUserModelId -match '(?i)spotify' })
            $session = $sessions | Where-Object { $_.GetPlaybackInfo().PlaybackStatus.ToString() -eq 'Playing' } | Select-Object -First 1
            if ($null -eq $session) { $session = $sessions | Select-Object -First 1 }
            if ($null -eq $session) {
                $lastKey = ''; $cover = ''
                Emit @{ available = $false; status = 'Apri Spotify e riproduci un brano' }
            } else {
                $props = Await ($session.TryGetMediaPropertiesAsync()) ([Windows.Media.Control.GlobalSystemMediaTransportControlsSessionMediaProperties])
                $timeline = $session.GetTimelineProperties()
                $info = $session.GetPlaybackInfo()
                $playing = $info.PlaybackStatus.ToString() -eq 'Playing'
                $duration = [Math]::Max(0, ($timeline.EndTime - $timeline.StartTime).TotalSeconds)
                $position = ($timeline.Position - $timeline.StartTime).TotalSeconds
                # Windows timeline positions refer to LastUpdatedTime, not the polling time.
                if ($playing -and $timeline.LastUpdatedTime.Year -gt 2000) {
                    $position += [Math]::Max(0, ([DateTimeOffset]::UtcNow - $timeline.LastUpdatedTime).TotalSeconds)
                }
                $position = [Math]::Max(0, [Math]::Min($duration, $position))
                $key = "$($props.Title)`0$($props.Artist)`0$($props.AlbumTitle)"
                if ($key -ne $lastKey) { $cover = ''; $lastKey = $key }
                if (-not $cover -and $null -ne $props.Thumbnail) {
                    $stream = $null; $reader = $null
                    try {
                        $stream = Await ($props.Thumbnail.OpenReadAsync()) ([Windows.Storage.Streams.IRandomAccessStreamWithContentType])
                        # Hard limit: never send an unbounded image through the pipe.
                        if ($stream.Size -gt 0 -and $stream.Size -le 2097152) {
                            $reader = [Windows.Storage.Streams.DataReader]::new($stream)
                            $loaded = Await ($reader.LoadAsync([uint32]$stream.Size)) ([uint32])
                            $bytes = New-Object byte[] $loaded
                            $reader.ReadBytes($bytes)
                            $cover = [Convert]::ToBase64String($bytes)
                        }
                    } catch { $cover = '' }
                    finally {
                        if ($null -ne $reader) { $reader.Dispose() }
                        if ($null -ne $stream) { $stream.Dispose() }
                    }
                }
                Emit @{
                    available = -not [string]::IsNullOrWhiteSpace($props.Title)
                    title = [string]$props.Title; artist = [string]$props.Artist; album = [string]$props.AlbumTitle
                    duration = $duration; position = $position; playing = $playing; cover = $cover
                    status = 'Nessun brano disponibile'
                }
            }
        } catch {
            Emit @{ available = $false; status = 'Sessione Spotify non disponibile' }
        }
        Start-Sleep -Milliseconds 1000
    }
} catch {
    Emit @{ available = $false; status = 'API multimediali Windows non disponibili' }
    exit 1
}
