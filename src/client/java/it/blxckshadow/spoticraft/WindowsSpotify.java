package it.blxckshadow.spoticraft;

import com.google.gson.*;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import javax.imageio.ImageIO;
import java.awt.image.BufferedImage;
import java.io.*;
import java.nio.charset.StandardCharsets;
import java.nio.file.*;
import java.util.*;
import java.util.concurrent.*;
import java.util.function.Consumer;

/** A single supervised, read-only PowerShell process; no listening ports or credentials. */
public final class WindowsSpotify implements AutoCloseable {
    private static final Logger LOGGER = LoggerFactory.getLogger("spoticraft");
    private final Map<String, Long> diagnosticTimes = new LinkedHashMap<>();
    private final Consumer<Playback> sink;
    private final ExecutorService worker = Executors.newSingleThreadExecutor(r -> {
        Thread t = new Thread(r, "Spoticraft-Windows"); t.setDaemon(true); return t;
    });
    private final ScheduledExecutorService watchdog = Executors.newSingleThreadScheduledExecutor(r -> {
        Thread t = new Thread(r, "Spoticraft-watchdog"); t.setDaemon(true); return t;
    });
    private volatile boolean closed;
    private volatile Process process;
    private volatile long heartbeat;
    private String lastCover = "";
    private int[] pixels;
    public WindowsSpotify(Consumer<Playback> sink) { this.sink = sink; }
    public void start(Path directory) {
        if (!System.getProperty("os.name", "").toLowerCase(Locale.ROOT).startsWith("windows")) {
            sink.accept(Playback.idle("Spoticraft richiede Windows 10/11")); return;
        }
        watchdog.scheduleAtFixedRate(() -> {
            Process p = process;
            if (p != null && System.nanoTime() - heartbeat > TimeUnit.SECONDS.toNanos(20)) {
                sink.accept(Playback.idle("Connessione Spotify interrotta")); p.destroyForcibly();
            }
        }, 5, 5, TimeUnit.SECONDS);
        worker.submit(() -> run(directory));
    }
    private void run(Path directory) {
        try {
            Files.createDirectories(directory);
            Path script = directory.resolve("spotify-session.ps1");
            for (String resource : List.of("spotify-session.ps1", "SpotifyBridge.cs")) {
                try (InputStream in = WindowsSpotify.class.getResourceAsStream("/native/" + resource)) {
                    if (in == null) throw new IOException("Missing bridge resource: " + resource);
                    Files.copy(in, directory.resolve(resource), StandardCopyOption.REPLACE_EXISTING);
                }
            }
            Path powershell = Path.of(System.getenv("SystemRoot"), "System32", "WindowsPowerShell", "v1.0", "powershell.exe");
            while (!closed) {
                try {
                    heartbeat = System.nanoTime();
                    Process p = new ProcessBuilder(powershell.toString(), "-NoLogo", "-NoProfile", "-NonInteractive",
                            "-ExecutionPolicy", "Bypass", "-File", script.toAbsolutePath().toString())
                            .redirectError(ProcessBuilder.Redirect.DISCARD).start();
                    process = p;
                    if (closed) { p.destroyForcibly(); break; }
                    try (BufferedReader reader = p.inputReader(StandardCharsets.UTF_8)) {
                        String line;
                        while (!closed && (line = reader.readLine()) != null) {
                            heartbeat = System.nanoTime();
                            if (line.length() > 3_000_000) throw new IOException("Oversized bridge message");
                            try { sink.accept(decode(JsonParser.parseString(line).getAsJsonObject())); }
                            catch (RuntimeException | IOException e) { sink.accept(Playback.idle("Dati Spotify non disponibili")); }
                        }
                    } finally { p.destroyForcibly(); process = null; }
                } catch (IOException e) {
                    sink.accept(Playback.idle("Impossibile avviare il bridge Windows"));
                }
                if (!closed) {
                    sink.accept(Playback.idle("Riconnessione a Spotify…"));
                    Thread.sleep(5000);
                }
            }
        } catch (InterruptedException e) { Thread.currentThread().interrupt(); }
        catch (Exception e) { sink.accept(Playback.idle("Bridge Windows non disponibile")); }
    }
    private Playback decode(JsonObject json) throws IOException {
        logDiagnostics(json);
        if (!json.has("available") || !json.get("available").getAsBoolean()) {
            lastCover = ""; pixels = null;
            return Playback.idle(string(json, "status"));
        }
        String cover = string(json, "cover");
        if (!cover.equals(lastCover)) {
            pixels = null;
            try {
                if (!cover.isEmpty()) {
                    byte[] bytes = Base64.getDecoder().decode(cover);
                    try (var input = ImageIO.createImageInputStream(new ByteArrayInputStream(bytes))) {
                        var readers = ImageIO.getImageReaders(input);
                        if (readers.hasNext()) {
                            var reader = readers.next();
                            try {
                                reader.setInput(input);
                                int w = reader.getWidth(0), h = reader.getHeight(0);
                                if (w > 0 && h > 0 && w <= 4096 && h <= 4096) {
                                    var params = reader.getDefaultReadParam();
                                    params.setSourceSubsampling(Math.max(1, w / 48), Math.max(1, h / 48), 0, 0);
                                    BufferedImage image = reader.read(0, params);
                                    int[] scaled = new int[48 * 48];
                                    for (int y = 0; y < 48; y++) for (int x = 0; x < 48; x++)
                                        scaled[y * 48 + x] = image.getRGB(x * image.getWidth() / 48, y * image.getHeight() / 48) | 0xff000000;
                                    pixels = scaled;
                                }
                            } finally { reader.dispose(); }
                        }
                    }
                }
            } catch (IOException | RuntimeException badImage) {
                // Artwork is optional: corrupt thumbnails must not hide title/timeline.
                pixels = null;
            }
            lastCover = cover;
        }
        double duration = finite(json, "duration"), position = finite(json, "position");
        return new Playback(string(json, "title"), string(json, "artist"), string(json, "album"), duration,
                Math.min(position, duration), json.get("playing").getAsBoolean(), System.nanoTime(), pixels, "");
    }
    private void logDiagnostics(JsonObject json) {
        if (!json.has("diagnostics") || !json.get("diagnostics").isJsonArray()) return;
        for (JsonElement element : json.getAsJsonArray("diagnostics")) {
            if (!element.isJsonObject()) continue;
            JsonObject d = element.getAsJsonObject();
            String stage = diagnosticText(d, "stage"), type = diagnosticText(d, "type");
            String code = diagnosticText(d, "hresult");
            String key = stage + ":" + type + ":" + code;
            long now = System.nanoTime();
            Long previous = diagnosticTimes.get(key);
            if (previous != null && now - previous < TimeUnit.SECONDS.toNanos(60)) continue;
            if (diagnosticTimes.size() >= 32) diagnosticTimes.remove(diagnosticTimes.keySet().iterator().next());
            diagnosticTimes.put(key, now);
            LOGGER.warn("Spoticraft Windows bridge [{}] {} (HRESULT {}): {}",
                    stage, type, code, diagnosticText(d, "message"));
        }
    }
    private static String diagnosticText(JsonObject object, String key) {
        if (!object.has(key) || !object.get(key).isJsonPrimitive()) return "";
        String value = object.get(key).getAsString().replaceAll("[\\p{Cc}§]", " ");
        return value.substring(0, Math.min(value.length(), 500));
    }
    private static double finite(JsonObject o, String key) {
        double n = o.has(key) ? o.get(key).getAsDouble() : 0;
        return Double.isFinite(n) ? Math.max(0, n) : 0;
    }
    static String string(JsonObject o, String key) {
        return o.has(key) && !o.get(key).isJsonNull() ? o.get(key).getAsString() : "";
    }
    @Override public void close() {
        closed = true;
        Process p = process;
        if (p != null) p.destroyForcibly();
        worker.shutdownNow(); watchdog.shutdownNow();
    }
}
