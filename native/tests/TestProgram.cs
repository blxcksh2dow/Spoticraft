namespace Spoticraft.Tests {
    using System;
    using System.Web.Script.Serialization;
    using Spoticraft.Native;
    public static class TestProgram {
        [MTAThread]
        public static int Main() {
            try {
                Console.WriteLine(WindowsBridgeTests.Run());
                var snapshot = new Snapshot { available = true, title = "Test \"song\" 日本語", duration = 180 };
                snapshot.diagnostics.Add(new Diagnostic("cover-read", new Exception("Test error")));
                var wire = new JavaScriptSerializer().Deserialize<Snapshot>(Program.Serialize(snapshot));
                if (!wire.available || wire.title != snapshot.title || wire.duration != 180 || wire.diagnostics[0].stage != "cover-read")
                    throw new Exception("JSON round-trip failed");
                Console.WriteLine("Production JSON serializer test passed.");
                return 0;
            } catch (Exception e) { Console.Error.WriteLine(e); return 1; }
        }
    }
}
