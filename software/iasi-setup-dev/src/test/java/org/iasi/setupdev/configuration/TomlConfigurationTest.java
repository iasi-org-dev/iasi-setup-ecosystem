package org.iasi.setupdev.configuration;

import static org.junit.jupiter.api.Assertions.*;

import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.util.List;
import org.iasi.args.access.ArgumentAccess;
import org.iasi.args.validation.ArgumentException;
import org.junit.jupiter.api.Test;

/**
 * Checks shared TOML stream parsing and the caller's ownership of the source stream.
 *
 * @author Javier G. Grandez
 * @since 0.1.0
 * @version 0.1.0
 * @history 2026-11-20 | 0.1.0 | Cover resource-compatible parsing and malformed TOML streams.
 */
class TomlConfigurationTest {
    @Test
    void parsesTextValuesWithoutClosingBorrowedStream() throws Exception {
        TrackingStream stream = new TrackingStream("logs='a,b'\nverbose=2\nservers=['one','two']\n");
        var arguments = new TomlConfiguration().read(stream);
        assertEquals(List.of("a,b"), ArgumentAccess.values(arguments, "logs"));
        assertEquals(List.of("2"), ArgumentAccess.values(arguments, "verbose"));
        assertEquals(List.of("one", "two"), ArgumentAccess.values(arguments, "servers"));
        assertFalse(stream.closed);
    }

    @Test
    void rejectsMalformedStreamsBeforeApplyingAnyLayer() {
        var stream = new ByteArrayInputStream("logs=[".getBytes(StandardCharsets.UTF_8));
        assertThrows(ArgumentException.class, () -> new TomlConfiguration().read(stream));
    }

    /**
     * Records stream closure independently of ByteArrayInputStream's permissive close behavior.
     *
     * @author Javier G. Grandez
     * @since 0.1.0
     * @version 0.1.0
     * @history 2026-11-20 | 0.1.0 | Detect accidental closure of a borrowed configuration stream.
     */
    private static final class TrackingStream extends ByteArrayInputStream {
        private boolean closed;

        private TrackingStream(String text) {
            super(text.getBytes(StandardCharsets.UTF_8));
        }

        @Override
        public void close() throws IOException {
            closed = true;
            super.close();
        }
    }
}
