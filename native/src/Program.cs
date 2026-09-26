using System;
using System.IO;
using System.Text;
using System.Threading;
using System.Web.Script.Serialization;
using System.Reflection;

[assembly: AssemblyTitle("Spoticraft Windows Media Bridge")]
[assembly: AssemblyDescription("Read-only Windows media session reader for Spoticraft. JSON output only.")]
[assembly: AssemblyProduct("Spoticraft")]
[assembly: AssemblyVersion("26.2.0.0")]
[assembly: AssemblyFileVersion("26.2.0.0")]

namespace Spoticraft.Native {
    public static class Program {
        public static string Serialize(Snapshot snapshot) {
            return new JavaScriptSerializer { MaxJsonLength = 3000000 }.Serialize(snapshot);
        }
        [MTAThread]
        public static int Main(string[] args) {
            // Only an optional single-poll diagnostic mode. Never accepts code, URLs or commands.
            if (args.Length > 1 || (args.Length == 1 && args[0] != "--once")) return 2;
            bool once = args.Length == 1;
            try {
                Console.OutputEncoding = new UTF8Encoding(false);
                var bridge = new Bridge();
                do {
                    Console.WriteLine(Serialize(bridge.Poll()));
                    Console.Out.Flush();
                    if (once) break;
                    Thread.Sleep(1000);
                } while (true);
                return 0;
            } catch (IOException) {
                // Minecraft closed the stdout pipe: terminate, do not leave an orphan process.
                return 0;
            } catch (Exception e) {
                try { Console.WriteLine(Serialize(Bridge.Failure("bridge-process", e))); }
                catch { }
                return 1;
            }
        }
    }
}
