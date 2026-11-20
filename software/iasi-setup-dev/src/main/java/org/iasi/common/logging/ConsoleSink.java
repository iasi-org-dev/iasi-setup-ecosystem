package org.iasi.common.logging;

import org.iasi.base.Verbosity;

import java.io.PrintStream;
import java.time.format.DateTimeFormatter;
import java.time.Clock;
import java.time.ZonedDateTime;

/**
 * Formats and filters console messages while preserving borrowed output streams.
 *
 * @author Javier G. Grandez
 * @since 0.1.0
 * @version 0.1.0
 * @history 2026-11-19 | 0.1.0 | Establish structural documentation and component responsibilities.
 */
public final class ConsoleSink implements LogSink {
    private static final DateTimeFormatter TIME = DateTimeFormatter.ofPattern("HH:mm:ss");
    private final PrintStream out;
    private final PrintStream err;
    private final Verbosity verbosity;
    private final boolean colors;

    public ConsoleSink(PrintStream out, PrintStream err, Verbosity verbosity, boolean colors) {
        this.out = out;
        this.err = err;
        this.verbosity = verbosity;
        this.colors = colors;
    }

    @Override
    public void write(LogEvent event) {
        print(event.severity(), event.timestamp(), event.message());
    }

    public void write(Severity severity, String message, Clock clock) {
        print(severity, ZonedDateTime.now(clock), Redactor.sanitize(message));
    }

    private void print(Severity severity, ZonedDateTime time, String message) {
        if (!includes(severity)) return;
        String line = time.format(TIME) + " - " + message;
        if (colors && !severity.color().isEmpty()) line = "\u001b[" + severity.color() + "m" + line + "\u001b[0m";
        PrintStream destination = severity == Severity.ERROR ? err : out;
        destination.println(line);
    }

    /**
     * Flushes borrowed stdout/stderr streams without closing them.
     */
    @Override
    public void close() {
        out.flush();
        err.flush();
    }

    private boolean includes(Severity severity) {
        if (severity == Severity.ERROR) return true;
        if (verbosity == Verbosity.SILENT) return false;
        if (severity == Severity.TRACE) return verbosity == Verbosity.VERY_VERBOSE;
        if (severity == Severity.DEBUG) return verbosity == Verbosity.VERBOSE || verbosity == Verbosity.VERY_VERBOSE;
        return true;
    }
}
