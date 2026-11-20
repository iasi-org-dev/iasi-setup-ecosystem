package org.iasi.common.logging;

import org.iasi.base.Verbosity;

import java.io.IOException;
import java.io.PrintStream;
import java.time.Clock;
import java.time.ZonedDateTime;
import org.iasi.common.i18n.MessageCatalog;

/**
 * Localizes and sanitizes events before distributing them to persistent and console sinks.
 *
 * @author Javier G. Grandez
 * @since 0.1.0
 * @version 0.1.0
 * @history 2026-11-19 | 0.1.0 | Establish structural documentation and component responsibilities.
 */
public final class Logger implements AutoCloseable {
    private final MessageCatalog catalog;
    private final Clock clock;
    private final String component;
    private final LogSink persistent;
    private final LogSink console;

    public Logger(MessageCatalog catalog, Clock clock, String component, LogSink persistent, LogSink console) {
        this.catalog = catalog;
        this.clock = clock;
        this.component = component;
        this.persistent = persistent;
        this.console = console;
    }

    /**
     * Writes the persistent sink before the console, so a persistence failure cannot announce a successfully logged event.
     * @throws IOException if either output backend fails
     */
    public void emit(MessageDefinition definition, Object... arguments) throws IOException {
        ZonedDateTime time = ZonedDateTime.now(clock);
        String text = catalog.text(definition.key(), arguments);
        LogEvent event = new LogEvent(time, definition.code(), definition.severity(), component, text);
        persistent.write(event);
        console.write(event);
    }

    /**
     * Reports a bootstrap error without opening a file or requiring a persistent logging backend.
     */
    public static void earlyError(MessageCatalog catalog, PrintStream err, Clock clock, MessageDefinition definition, Object... arguments) {
        String text = catalog.text(definition.key(), arguments);
        LogEvent event = new LogEvent(ZonedDateTime.now(clock), definition.code(), definition.severity(), "bootstrap", text);
        new ConsoleSink(err, err, Verbosity.SILENT, false).write(event);
    }

    /**
     * Attempts to close both sinks, retaining a second failure as a suppressed exception.
     */
    @Override
    public void close() throws IOException {
        try (LogSink first = persistent; LogSink second = console) {
            // El cierre automático conserva también cualquier segundo fallo de liberación.
        }
    }
}
