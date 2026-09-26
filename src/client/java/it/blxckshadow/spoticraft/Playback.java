package it.blxckshadow.spoticraft;

/** Immutable snapshot. All time arithmetic is monotonic and independent of game ticks. */
public record Playback(String title, String artist, String album, double duration,
                       double position, boolean playing, long capturedNanos, int[] cover, String status) {
    public static Playback idle(String status) {
        return new Playback("", "", "", 0, 0, false, System.nanoTime(), null, status);
    }
    public boolean available() { return !title.isBlank(); }
    public String key() { return title + "\u0000" + artist + "\u0000" + album + "\u0000" + Math.round(duration); }
    public double positionAt(long now) {
        double elapsed = playing ? Math.max(0, (now - capturedNanos) / 1_000_000_000.0) : 0;
        return Math.max(0, Math.min(duration, position + elapsed));
    }
    public static String time(double seconds) {
        if (!Double.isFinite(seconds) || seconds < 0) return "--:--";
        long s = (long) seconds;
        return "%d:%02d".formatted(s / 60, s % 60);
    }
}
