package it.blxckshadow.spoticraft;

import java.io.IOException;
import java.nio.file.*;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import static org.junit.jupiter.api.Assertions.*;

class BridgeBinaryTest {
    @TempDir Path directory;
    @Test void acceptsMatchingHash() throws Exception {
        Path file = directory.resolve("fixture");
        Files.writeString(file, "abc");
        assertDoesNotThrow(() -> BridgeBinary.verify(file, "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"));
    }
    @Test void refusesTamperedOrMissingFiles() throws Exception {
        Path file = directory.resolve("fixture");
        Files.writeString(file, "modified");
        assertThrows(IOException.class, () -> BridgeBinary.verify(file, "0".repeat(64)));
        Files.delete(file);
        assertThrows(IOException.class, () -> BridgeBinary.verify(file, "0".repeat(64)));
    }
    @Test void extractsAndReusesBundledExecutableWithoutExecutingIt() throws Exception {
        var first = BridgeBinary.extract(directory);
        assertTrue(Files.size(first.path()) > 0);
        BridgeBinary.verify(first.path(), first.sha256());
        assertEquals(first, BridgeBinary.extract(directory));
        Files.writeString(first.path(), "modified");
        assertThrows(IOException.class, () -> BridgeBinary.extract(directory));
    }
}
