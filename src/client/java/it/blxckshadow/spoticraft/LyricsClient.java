package it.blxckshadow.spoticraft;

import com.google.gson.*;
import java.io.*;
import java.net.*;
import java.net.http.*;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.*;
import java.util.concurrent.*;

/** Bounded in-memory cache. Network calls never happen on Minecraft's render/tick thread. */
public final class LyricsClient implements AutoCloseable {
    public record Result(String key, Lyrics lyrics) {}
    private record Cached(Lyrics lyrics, long expires) {}
    private final ScheduledExecutorService worker = Executors.newSingleThreadScheduledExecutor(r -> {
        Thread t = new Thread(r, "Spoticraft-lyrics"); t.setDaemon(true); return t;
    });
    private final ScheduledExecutorService timeouts = Executors.newSingleThreadScheduledExecutor(r -> {
        Thread t = new Thread(r, "Spoticraft-network-timeout"); t.setDaemon(true); return t;
    });
    private volatile InputStream activeBody;
    private final HttpClient http = HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(5)).build();
    private final Map<String, Cached> cache = new LinkedHashMap<>(32, .75f, true) {
        @Override protected boolean removeEldestEntry(Map.Entry<String, Cached> e) { return size() > 64; }
    };
    private volatile Playback wanted = Playback.idle("");
    private volatile Result result = new Result("", Lyrics.status("Ricerca testo…"));
    private volatile boolean closed;
    public LyricsClient() { worker.scheduleWithFixedDelay(this::poll, 0, 1, TimeUnit.SECONDS); }
    public void request(Playback playback) { wanted = playback; }
    public Lyrics forTrack(String key) {
        Result r = result;
        return r.key.equals(key) ? r.lyrics : Lyrics.status("Ricerca testo…");
    }
    private void poll() {
        Playback p = wanted;
        if (!p.available() || closed) return;
        try {
            Cached hit = cache.get(p.key());
            if (hit == null || hit.expires < System.nanoTime()) {
                hit = fetch(p); cache.put(p.key(), hit);
            }
            // Never let a slow request display lyrics belonging to the previous song.
            if (wanted.key().equals(p.key())) result = new Result(p.key(), hit.lyrics);
        } catch (InterruptedException e) { Thread.currentThread().interrupt(); }
        catch (Exception e) {
            Lyrics message = Lyrics.status("Testo offline / servizio non disponibile");
            cache.put(p.key(), new Cached(message, System.nanoTime() + TimeUnit.SECONDS.toNanos(60)));
            if (wanted.key().equals(p.key())) result = new Result(p.key(), message);
        }
    }
    private Cached fetch(Playback p) throws IOException, InterruptedException {
        String query = "track_name=" + encode(p.title()) + "&artist_name=" + encode(p.artist());
        if (!p.album().isBlank()) query += "&album_name=" + encode(p.album());
        if (p.duration() > 0) query += "&duration=" + Math.round(p.duration());
        HttpRequest request = HttpRequest.newBuilder(URI.create("https://lrclib.net/api/get?" + query))
                .timeout(Duration.ofSeconds(8)).header("User-Agent", "Spoticraft/26.2 (Minecraft Fabric client)")
                .header("Accept", "application/json").GET().build();
        HttpResponse<InputStream> response = http.send(request, HttpResponse.BodyHandlers.ofInputStream());
        InputStream stream = response.body();
        activeBody = stream;
        if (closed) { stream.close(); throw new InterruptedException("Closing"); }
        ScheduledFuture<?> deadline = timeouts.schedule(() -> {
            try { stream.close(); } catch (IOException ignored) { }
        }, 8, TimeUnit.SECONDS);
        try (InputStream body = stream) {
            if (response.statusCode() == 404) return cached(Lyrics.status("Testo non disponibile"), 600);
            if (response.statusCode() != 200) return cached(Lyrics.status("Servizio testi non disponibile"), 60);
            byte[] bytes = body.readNBytes(512_001);
            if (bytes.length > 512_000) throw new IOException("Oversized lyrics response");
            JsonObject j = JsonParser.parseString(new String(bytes, StandardCharsets.UTF_8)).getAsJsonObject();
            if (j.has("instrumental") && j.get("instrumental").getAsBoolean())
                return cached(Lyrics.status("♪ Brano strumentale"), 3600);
            return cached(Lyrics.parse(WindowsSpotify.string(j, "syncedLyrics"), WindowsSpotify.string(j, "plainLyrics")), 3600);
        } finally {
            deadline.cancel(false);
            activeBody = null;
        }
    }
    private static Cached cached(Lyrics lyrics, long seconds) { return new Cached(lyrics, System.nanoTime() + TimeUnit.SECONDS.toNanos(seconds)); }
    private static String encode(String s) { return URLEncoder.encode(s, StandardCharsets.UTF_8); }
    @Override public void close() {
        closed = true;
        InputStream body = activeBody;
        if (body != null) try { body.close(); } catch (IOException ignored) { }
        worker.shutdownNow(); timeouts.shutdownNow(); http.shutdownNow();
    }
}
