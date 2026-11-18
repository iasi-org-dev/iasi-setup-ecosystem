package org.iasi.common.logging;

import static org.junit.jupiter.api.Assertions.*;

import java.io.ByteArrayOutputStream;
import java.io.PrintStream;
import java.nio.charset.StandardCharsets;
import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import org.iasi.base.Verbosity;
import org.junit.jupiter.api.Test;

class ConsoleSinkTest {
    private static final Clock CLOCK = Clock.fixed(Instant.parse("2026-11-18T12:34:56Z"), ZoneOffset.UTC);

    @Test
    void formatsMessagesAndRoutesErrorsWithTheirColors() {
        var out = new ByteArrayOutputStream();
        var err = new ByteArrayOutputStream();
        ConsoleSink console = new ConsoleSink(new PrintStream(out), new PrintStream(err), Verbosity.NORMAL, true);
        console.write(Severity.WARNING, "aviso", CLOCK);
        console.write(Severity.ERROR, "error", CLOCK);
        assertEquals("\u001b[33m12:34:56 - aviso\u001b[0m" + System.lineSeparator(), out.toString(StandardCharsets.UTF_8));
        assertEquals("\u001b[31m12:34:56 - error\u001b[0m" + System.lineSeparator(), err.toString(StandardCharsets.UTF_8));
    }

    @Test
    void omitsEventCodesAndColorsWhenDisabled() {
        var out = new ByteArrayOutputStream();
        var stream = new PrintStream(out);
        ConsoleSink console = new ConsoleSink(stream, stream, Verbosity.NORMAL, false);
        console.write(new LogEvent(java.time.ZonedDateTime.now(CLOCK), "TST01001", Severity.INFO, "test", "mensaje"));
        assertEquals("12:34:56 - mensaje" + System.lineSeparator(), out.toString(StandardCharsets.UTF_8));
    }
}
