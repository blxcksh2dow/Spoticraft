package it.blxckshadow.spoticraft;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import java.nio.file.*;
import static org.junit.jupiter.api.Assertions.*;

class WidgetConfigTest {
    @TempDir Path directory;
    @Test void createsDefaults() throws Exception {
        Path file = directory.resolve("nested/widget.properties");
        WidgetConfig c = WidgetConfig.load(file);
        assertTrue(Files.exists(file));
        assertEquals(8, c.x()); assertEquals(280, c.width()); assertTrue(c.lyricsEnabled());
    }
    @Test void malformedNumbersAreSafeAndRangesClamped() throws Exception {
        Path file = directory.resolve("widget.properties");
        Files.writeString(file, "x=-5\ny=oops\nwidth=9999\nplainScrollSeconds=-1\nlyricsEnabled=false\n");
        WidgetConfig c = WidgetConfig.load(file);
        assertEquals(0, c.x()); assertEquals(8, c.y()); assertEquals(600, c.width());
        assertEquals(0, c.plainScrollSeconds()); assertFalse(c.lyricsEnabled());
    }
}
