package it.blxckshadow.spoticraft;

import java.util.*;
import java.util.regex.*;

public record Lyrics(List<Line> synced, List<String> plain, String message) {
    private static final Pattern TAG = Pattern.compile("\\[(\\d+):(\\d{2})(?:[.:](\\d{1,3}))?]");
    private static final Pattern OFFSET = Pattern.compile("\\[offset:([+-]?\\d+)]", Pattern.CASE_INSENSITIVE);
    public record Line(double seconds, String text) {}
    public Lyrics { synced = List.copyOf(synced); plain = List.copyOf(plain); }
    public static Lyrics status(String message) { return new Lyrics(List.of(), List.of(), message); }
    public static Lyrics parse(String lrc, String plainText) {
        List<Line> timed = new ArrayList<>();
        Matcher offsetTag = OFFSET.matcher(lrc);
        double offset = offsetTag.find() ? Double.parseDouble(offsetTag.group(1)) / 1000 : 0;
        for (String line : lrc.split("\\R")) {
            Matcher m = TAG.matcher(line);
            List<Double> times = new ArrayList<>();
            int end = 0;
            while (m.find()) {
                double fraction = m.group(3) == null ? 0 : Double.parseDouble("0." + m.group(3));
                times.add(Integer.parseInt(m.group(1)) * 60 + Integer.parseInt(m.group(2)) + fraction - offset);
                end = m.end();
            }
            String text = line.substring(end).strip();
            for (double time : times) timed.add(new Line(time, text));
        }
        timed.sort(Comparator.comparingDouble(Line::seconds));
        List<String> plain = plainText.lines().map(String::strip).filter(s -> !s.isEmpty()).toList();
        return new Lyrics(timed, plain, timed.isEmpty() && plain.isEmpty() ? "Testo non disponibile" : "");
    }
    public String[] pair(double position, int plainIndex) {
        if (!synced.isEmpty()) {
            int low = 0, high = synced.size();
            while (low < high) {
                int mid = (low + high) >>> 1;
                if (synced.get(mid).seconds <= position) low = mid + 1;
                else high = mid;
            }
            int current = low - 1;
            return new String[]{current < 0 ? "♪" : synced.get(current).text,
                    low < synced.size() ? synced.get(low).text : ""};
        }
        if (!plain.isEmpty()) {
            int i = Math.max(0, Math.min(plainIndex, plain.size() - 1));
            return new String[]{plain.get(i), i + 1 < plain.size() ? plain.get(i + 1) : ""};
        }
        return new String[]{message, ""};
    }
}
