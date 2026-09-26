package it.blxckshadow.spoticraft;

import java.io.*;
import java.nio.charset.StandardCharsets;
import java.nio.file.*;
import java.security.*;
import java.util.HexFormat;

/** Bundled, build-time compiled helper. No download, shell, elevated permissions or runtime compiler. */
final class BridgeBinary {
    record Verified(Path path, String sha256) {}
    static Verified extract(Path directory) throws IOException {
        String expected;
        try (InputStream in = resource("Spoticraft.Bridge.sha256")) {
            expected = new String(in.readAllBytes(), StandardCharsets.US_ASCII).strip();
        }
        if (!expected.matches("[0-9a-f]{64}")) throw new IOException("Invalid bundled bridge checksum");
        Path location = directory.resolve("bridge").resolve(expected);
        Files.createDirectories(location);
        Path executable = location.resolve("Spoticraft.Bridge.exe");
        if (Files.exists(executable)) {
            verify(executable, expected); // Never run a modified copy or silently replace it.
        } else {
            Path temporary = Files.createTempFile(location, "bridge-", ".tmp");
            try {
                try (InputStream in = resource("Spoticraft.Bridge.exe")) {
                    Files.copy(in, temporary, StandardCopyOption.REPLACE_EXISTING);
                }
                verify(temporary, expected);
                Files.move(temporary, executable);
            } finally { Files.deleteIfExists(temporary); }
        }
        return new Verified(executable, expected);
    }
    static void verify(Path file, String expected) throws IOException {
        try (InputStream in = Files.newInputStream(file)) {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            byte[] buffer = new byte[8192];
            for (int n; (n = in.read(buffer)) != -1;) digest.update(buffer, 0, n);
            String actual = HexFormat.of().formatHex(digest.digest());
            if (!actual.equals(expected)) throw new IOException("Bridge checksum mismatch; refusing to execute");
        } catch (NoSuchAlgorithmException impossible) { throw new IllegalStateException(impossible); }
    }
    private static InputStream resource(String name) throws IOException {
        InputStream in = BridgeBinary.class.getResourceAsStream("/native/" + name);
        if (in == null) throw new IOException("Missing bundled bridge: " + name);
        return in;
    }
}
