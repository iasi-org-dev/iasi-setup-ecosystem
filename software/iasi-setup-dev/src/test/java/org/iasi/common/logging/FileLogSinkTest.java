package org.iasi.common.logging;

import static org.junit.jupiter.api.Assertions.*;

import java.io.IOException;
import java.nio.file.Path;
import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

/**
 * Checks the agreed executable-and-timestamp log filename.
 *
 * @author Javier G. Grandez
 * @since 0.1.0
 * @version 0.1.0
 * @history 2026-11-19 | 0.1.0 | Establish structural documentation and component responsibilities.
 */
class FileLogSinkTest {
    @TempDir
    Path directory;

    @Test
    void usesExecutableAndExecutionTimestamp() throws IOException {
        Clock clock = Clock.fixed(Instant.parse("2026-11-18T10:20:30Z"), ZoneOffset.UTC);
        try (FileLogSink sink = new FileLogSink(directory, "iasi-setup-dev", clock, false)) {
            assertEquals(directory.resolve("iasi-setup-dev-20261118-102030.log"), sink.file());
        }
    }
}
