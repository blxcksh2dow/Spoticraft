// Compiled locally by Windows PowerShell 5.1 against Windows' own WinRT metadata.
// WinRT objects never cross the PowerShell boundary: only plain .NET DTOs do.
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Threading;
using Windows.Foundation;
using Windows.Media.Control;
using Windows.Storage.Streams;

namespace Spoticraft.Native {
    public sealed class Diagnostic {
        public string stage, type, message;
        public int hresult;
        public Diagnostic(string stage, Exception error) {
            Exception cause = error.GetBaseException();
            this.stage = stage; type = cause.GetType().FullName;
            message = cause.Message; hresult = cause.HResult;
        }
    }
    public sealed class Snapshot {
        public bool available, playing;
        public string title = "", artist = "", album = "", cover = "", status = "";
        public double duration, position;
        public List<Diagnostic> diagnostics = new List<Diagnostic>();
    }
    public sealed class Media {
        public string Title, Artist, Album;
        public Func<List<Diagnostic>, string> ReadCover;
    }
    public sealed class Timeline {
        public TimeSpan Start, End, Position;
        public DateTimeOffset Updated;
    }
    // Seam for deterministic regression tests without Spotify or a logged-in desktop.
    public interface ISession {
        string AppId { get; }
        bool IsPlaying();
        Media ReadMedia();
        Timeline ReadTimeline();
    }
    internal sealed class WindowsSession : ISession {
        private readonly GlobalSystemMediaTransportControlsSession session;
        public WindowsSession(GlobalSystemMediaTransportControlsSession session) { this.session = session; }
        public string AppId { get { return session.SourceAppUserModelId; } }
        public bool IsPlaying() {
            var info = session.GetPlaybackInfo();
            return info != null && info.PlaybackStatus == GlobalSystemMediaTransportControlsSessionPlaybackStatus.Playing;
        }
        public Media ReadMedia() {
            var properties = Bridge.Wait(session.TryGetMediaPropertiesAsync());
            if (properties == null) throw new InvalidOperationException("Windows returned no media properties");
            var thumbnail = properties.Thumbnail;
            return new Media { Title = properties.Title, Artist = properties.Artist, Album = properties.AlbumTitle,
                ReadCover = thumbnail == null ? (Func<List<Diagnostic>, string>)null : d => Bridge.ReadThumbnail(thumbnail, d) };
        }
        public Timeline ReadTimeline() {
            var t = session.GetTimelineProperties();
            return t == null ? null : new Timeline { Start = t.StartTime, End = t.EndTime,
                Position = t.Position, Updated = t.LastUpdatedTime };
        }
    }
    public sealed class Bridge {
        private GlobalSystemMediaTransportControlsSessionManager manager;
        private string lastKey = "", cachedCover = "";
        private DateTime retryCoverAt = DateTime.MinValue;
        public static T Wait<T>(IAsyncOperation<T> operation) {
            // Use the OS's split WinRT metadata directly. Framework AsTask extensions
            // reference the merged SDK-only Windows.winmd, absent on end-user PCs.
            var timer = Stopwatch.StartNew();
            try {
                while (operation.Status == AsyncStatus.Started) {
                    if (timer.ElapsedMilliseconds >= 5000) {
                        operation.Cancel();
                        throw new TimeoutException("Windows media API timed out");
                    }
                    Thread.Sleep(10);
                }
                return operation.GetResults();
            } finally {
                try { operation.Close(); } catch { }
            }
        }
        public Snapshot Poll() {
            try {
                if (manager == null) manager = Wait(GlobalSystemMediaTransportControlsSessionManager.RequestAsync());
                var sessions = new List<ISession>();
                foreach (var s in manager.GetSessions()) sessions.Add(new WindowsSession(s));
                return PollSessions(sessions);
            } catch (Exception e) {
                manager = null; // Reacquire after the Windows session service restarts.
                return Failure("session-list", e);
            }
        }
        public Snapshot PollSessions(IEnumerable<ISession> sessions) {
            var diagnostics = new List<Diagnostic>();
            ISession fallback = null, selected = null;
            foreach (var s in sessions) {
                try {
                    if ((s.AppId ?? "").IndexOf("spotify", StringComparison.OrdinalIgnoreCase) < 0) continue;
                    if (fallback == null) fallback = s;
                    if (s.IsPlaying()) { selected = s; break; }
                } catch (Exception e) { diagnostics.Add(new Diagnostic("session-select", e)); }
            }
            selected = selected ?? fallback;
            Snapshot result;
            if (selected == null) {
                lastKey = ""; cachedCover = "";
                result = new Snapshot { status = "Apri Spotify e riproduci un brano" };
            } else result = ReadSession(selected);
            result.diagnostics.AddRange(diagnostics);
            return result;
        }
        public Snapshot ReadSession(ISession session) {
            Media media;
            try {
                media = session.ReadMedia();
                if (media == null) throw new InvalidOperationException("Windows returned no media properties");
            } catch (Exception e) { return Failure("media-properties", e); }
            var result = new Snapshot { title = media.Title ?? "", artist = media.Artist ?? "", album = media.Album ?? "" };
            result.available = !String.IsNullOrWhiteSpace(result.title);
            result.status = result.available ? "" : "Nessun brano disponibile";
            try { result.playing = session.IsPlaying(); }
            catch (Exception e) { result.diagnostics.Add(new Diagnostic("playback", e)); }
            try {
                var timeline = session.ReadTimeline();
                if (timeline != null) {
                    result.duration = Math.Max(0, (timeline.End - timeline.Start).TotalSeconds);
                    result.position = (timeline.Position - timeline.Start).TotalSeconds;
                    if (result.playing && timeline.Updated.Year > 2000)
                        result.position += Math.Max(0, (DateTimeOffset.UtcNow - timeline.Updated).TotalSeconds);
                    result.position = Math.Max(0, Math.Min(result.duration, result.position));
                }
            } catch (Exception e) { result.diagnostics.Add(new Diagnostic("timeline", e)); }
            string key = result.title + "\0" + result.artist + "\0" + result.album;
            if (key != lastKey) { lastKey = key; cachedCover = ""; retryCoverAt = DateTime.MinValue; }
            if (cachedCover.Length == 0 && DateTime.UtcNow >= retryCoverAt) {
                retryCoverAt = DateTime.UtcNow.AddSeconds(10);
                try { cachedCover = media.ReadCover == null ? "" : media.ReadCover(result.diagnostics) ?? ""; }
                catch (Exception e) { result.diagnostics.Add(new Diagnostic("cover-read", e)); }
            }
            result.cover = cachedCover;
            return result;
        }
        public static string ReadThumbnail(IRandomAccessStreamReference thumbnail, List<Diagnostic> diagnostics) {
            IRandomAccessStreamWithContentType stream = null;
            IInputStream input = null;
            DataReader reader = null;
            try {
                stream = Wait(thumbnail.OpenReadAsync());
                if (stream.Size == 0 || stream.Size > 2097152) return "";
                input = stream.GetInputStreamAt(0);
                reader = new DataReader(input);
                uint loaded = Wait(reader.LoadAsync((uint)stream.Size));
                var bytes = new byte[loaded];
                reader.ReadBytes(bytes);
                return Convert.ToBase64String(bytes);
            } finally {
                Close(reader, diagnostics);
                Close(input, diagnostics);
                Close(stream, diagnostics);
            }
        }
        public static void Close(IDisposable resource, List<Diagnostic> diagnostics) {
            if (resource == null) return;
            try { resource.Dispose(); }
            catch (Exception e) { diagnostics.Add(new Diagnostic("cover-close", e)); }
        }
        public static Snapshot Failure(string stage, Exception error) {
            var result = new Snapshot { status = "Spotify: errore " + stage + " (vedi latest.log)" };
            result.diagnostics.Add(new Diagnostic(stage, error));
            return result;
        }
    }
}
