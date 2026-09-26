package it.blxckshadow.spoticraft;

import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

class PlaybackTest {
    private Playback sample(boolean playing) {
        return new Playback("Song", "Artist", "Album", 120, 30, playing, 1_000_000_000, null, "");
    }
    @Test void advancesOutsideGameTicks() { assertEquals(32, sample(true).positionAt(3_000_000_000L)); }
    @Test void pauseDoesNotAdvance() { assertEquals(30, sample(false).positionAt(3_000_000_000L)); }
    @Test void clampsAtDuration() { assertEquals(120, sample(true).positionAt(300_000_000_000L)); }
    @Test void neverExtrapolatesBackwards() { assertEquals(30, sample(true).positionAt(0)); }
    @Test void timeFormat() {
        assertEquals("0:00", Playback.time(0));
        assertEquals("3:07", Playback.time(187.9));
        assertEquals("60:01", Playback.time(3601));
        assertEquals("--:--", Playback.time(Double.NaN));
    }
    @Test void idleClearsTrackAndCover() {
        assertFalse(Playback.idle("Offline").available());
        assertNull(Playback.idle("Offline").cover());
    }
}
