namespace Spoticraft.Tests {
    using System;
    using System.Collections.Generic;
    using Spoticraft.Native;
    using Windows.Storage.Streams;

    public static class WindowsBridgeTests {
        private static int checks;
        private static void Check(bool condition, string message) {
            if (!condition) throw new Exception("Assertion failed: " + message);
            checks++;
        }
        private sealed class FakeSession : ISession {
            public string Id = "Spotify.exe";
            public bool Playing = true, BadPlayback, BadMedia, BadTimeline;
            public Media Media = new Media { Title = "Test song", Artist = "Artist", Album = "Album" };
            public string AppId { get { return Id; } }
            public bool IsPlaying() { if (BadPlayback) throw new Exception("Stale session"); return Playing; }
            public Media ReadMedia() { if (BadMedia) throw new Exception("Media unavailable"); return Media; }
            public Timeline ReadTimeline() {
                if (BadTimeline) throw new Exception("Timeline unavailable");
                return new Timeline { Start = TimeSpan.Zero, End = TimeSpan.FromSeconds(180),
                    Position = TimeSpan.FromSeconds(20), Updated = DateTimeOffset.UtcNow.AddSeconds(-2) };
            }
        }
        private sealed class BadDisposable : IDisposable {
            public bool Called;
            public void Dispose() { Called = true; throw new Exception("Cleanup failure"); }
        }
        public static string Run() {
            checks = 0;
            // Real Windows WinRT objects: reproduces the COM boundary used for artwork.
            using (var stream = new InMemoryRandomAccessStream()) {
                using (var writer = new DataWriter(stream)) {
                    writer.WriteBytes(new byte[] { 1, 2, 3, 4, 5 });
                    Bridge.Wait(writer.StoreAsync().AsTask());
                    writer.DetachStream();
                }
                stream.Seek(0);
                var diagnostics = new List<Diagnostic>();
                string cover = Bridge.ReadThumbnail(RandomAccessStreamReference.CreateFromStream(stream), diagnostics);
                Check(cover == "AQIDBAU=", "Real WinRT stream returns the original bytes");
                Check(diagnostics.Count == 0, "Typed WinRT resources close successfully");
            }
            var errors = new List<Diagnostic>();
            var badResource = new BadDisposable();
            Bridge.Close(badResource, errors);
            Check(badResource.Called && errors.Count == 1 && errors[0].stage == "cover-close", "Cleanup errors are contained");
            var bridge = new Bridge();
            var s = new FakeSession();
            var result = bridge.ReadSession(s);
            Check(result.available && result.title == "Test song", "A track without artwork is available");
            Check(result.duration == 180 && result.position >= 22 && result.position < 25, "Timeline interpolation");
            s.Playing = false;
            result = bridge.ReadSession(s);
            Check(result.position == 20 && !result.playing, "Paused track stays still");
            s.BadTimeline = true;
            result = bridge.ReadSession(s);
            Check(result.available && result.duration == 0 && result.diagnostics[0].stage == "timeline", "Bad timeline keeps title");
            s.BadPlayback = true;
            result = bridge.ReadSession(s);
            Check(result.available && !result.playing, "Bad playback info keeps title");
            s = new FakeSession();
            int reads = 0;
            s.Media.ReadCover = d => { reads++; throw new Exception("Thumbnail unavailable"); };
            bridge = new Bridge();
            result = bridge.ReadSession(s);
            Check(result.available && result.cover == "" && result.diagnostics[0].stage == "cover-read", "Bad artwork keeps track");
            bridge.ReadSession(s);
            Check(reads == 1, "Artwork failures have retry backoff");
            s.Media.Title = "Next song";
            bridge.ReadSession(s);
            Check(reads == 2, "Track change resets retry");
            s.Media.Title = "Third song";
            s.Media.ReadCover = d => "AQIDBAU=";
            Check(bridge.ReadSession(s).cover == "AQIDBAU=", "Valid artwork is returned");
            s.Media.Title = "Fourth song";
            s.Media.ReadCover = null;
            Check(bridge.ReadSession(s).cover == "", "Track change clears stale cover");
            var stale = new FakeSession { BadPlayback = true };
            var good = new FakeSession();
            result = bridge.PollSessions(new ISession[] { stale, good });
            Check(result.available && result.playing && result.diagnostics[0].stage == "session-select", "Stale session does not hide healthy session");
            Check(!bridge.PollSessions(new ISession[0]).available, "Spotify closed clears the track");
            Check(!bridge.PollSessions(new ISession[] { new FakeSession { Id = "chrome.exe" } }).available, "Browser is not selected as Spotify");
            s.BadMedia = true;
            result = bridge.ReadSession(s);
            Check(!result.available && result.diagnostics[0].stage == "media-properties", "Metadata failure has a precise diagnostic");
            s.BadMedia = false; s.Media.Title = "";
            Check(!bridge.ReadSession(s).available, "Empty title is not successful playback");
            return checks + " Windows bridge checks passed (including real WinRT streams).";
        }
    }
}
