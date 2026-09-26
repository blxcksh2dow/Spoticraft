package it.blxckshadow.spoticraft;

import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

class LyricsTest {
    @Test void currentAndNextRespectTimestampBoundary() {
        Lyrics l = Lyrics.parse("[00:03.50]Uno\n[00:08.000]Due", "");
        assertArrayEquals(new String[]{"♪", "Uno"}, l.pair(0, 0));
        assertArrayEquals(new String[]{"Uno", "Due"}, l.pair(3.5, 0));
        assertArrayEquals(new String[]{"Due", ""}, l.pair(8, 0));
    }
    @Test void repeatedTagsAndUnorderedInputAreSorted() {
        Lyrics l = Lyrics.parse("[00:20][00:10]Ritornello\n[00:05]Intro", "");
        assertEquals(3, l.synced().size());
        assertArrayEquals(new String[]{"Intro", "Ritornello"}, l.pair(6, 0));
        assertEquals(20, l.synced().get(2).seconds());
    }
    @Test void hundredthsTenthsAndMilliseconds() {
        Lyrics l = Lyrics.parse("[00:01.1]a\n[00:02.12]b\n[00:03.123]c", "");
        assertEquals(1.1, l.synced().get(0).seconds(), .00001);
        assertEquals(2.12, l.synced().get(1).seconds(), .00001);
        assertEquals(3.123, l.synced().get(2).seconds(), .00001);
    }
    @Test void positiveOffsetDisplaysEarlier() {
        Lyrics l = Lyrics.parse("[offset:500]\n[00:02]Ciao", "");
        assertEquals(1.5, l.synced().getFirst().seconds());
    }
    @Test void emptyTimestampClearsPreviousLine() {
        Lyrics l = Lyrics.parse("[00:00]Voce\n[00:03]\n[00:05]Ripresa", "");
        assertArrayEquals(new String[]{"", "Ripresa"}, l.pair(4, 0));
    }
    @Test void plainTextClampsAndSkipsBlankLines() {
        Lyrics l = Lyrics.parse("[ar:someone]\ninvalid", "Uno\r\n\r\nDue\nTre");
        assertArrayEquals(new String[]{"Uno", "Due"}, l.pair(0, -3));
        assertArrayEquals(new String[]{"Tre", ""}, l.pair(0, 99));
    }
    @Test void emptyAndInstrumentalStates() {
        assertArrayEquals(new String[]{"Testo non disponibile", ""}, Lyrics.parse("", "").pair(0, 0));
        assertArrayEquals(new String[]{"♪ Brano strumentale", ""}, Lyrics.status("♪ Brano strumentale").pair(3, 0));
    }
    @Test void unicodeAndSeekingBackwards() {
        Lyrics l = Lyrics.parse("[00:01]Perché 日本語 🎵\n[00:10]Fine", "");
        assertEquals("Fine", l.pair(20, 0)[0]);
        assertEquals("Perché 日本語 🎵", l.pair(2, 0)[0]);
    }
    @Test void outputIsImmutable() {
        assertThrows(UnsupportedOperationException.class, () -> Lyrics.parse("", "Uno").plain().add("Due"));
    }
}
