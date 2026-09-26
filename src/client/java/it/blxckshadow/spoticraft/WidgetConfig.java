package it.blxckshadow.spoticraft;

import java.io.*;
import java.nio.file.*;
import java.util.Properties;

public record WidgetConfig(int x, int y, int width, boolean enabled, boolean lyricsEnabled, int plainScrollSeconds) {
    public static WidgetConfig load(Path path) throws IOException {
        Properties p = new Properties();
        if (Files.exists(path)) {
            try (Reader reader = Files.newBufferedReader(path)) { p.load(reader); }
        } else {
            Files.createDirectories(path.getParent());
            Files.writeString(path, """
                    # Spoticraft 26.2 - riavvia Minecraft dopo le modifiche
                    x=8
                    y=8
                    width=280
                    enabled=true
                    # true invia titolo, artista, album e durata a https://lrclib.net
                    lyricsEnabled=true
                    # 0 disabilita lo scorrimento automatico del testo non sincronizzato
                    plainScrollSeconds=6
                    """);
        }
        return new WidgetConfig(number(p, "x", 8, 0, 10000), number(p, "y", 8, 0, 10000),
                number(p, "width", 280, 180, 600), Boolean.parseBoolean(p.getProperty("enabled", "true")),
                Boolean.parseBoolean(p.getProperty("lyricsEnabled", "true")), number(p, "plainScrollSeconds", 6, 0, 60));
    }
    private static int number(Properties p, String key, int fallback, int min, int max) {
        try { return Math.max(min, Math.min(max, Integer.parseInt(p.getProperty(key)))); }
        catch (RuntimeException e) { return fallback; }
    }
}
