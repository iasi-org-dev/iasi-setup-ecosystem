package org.iasi.common.logging;

import org.iasi.base.Verbosity;

import java.io.IOException;
import java.io.PrintStream;
import java.nio.file.Path;
import java.time.Clock;
import org.iasi.common.i18n.MessageCatalog;

/**
 * Composes the default console and file backends without depending on application state.
 *
 * @author Javier G. Grandez
 * @since 0.1.0
 * @version 0.1.0
 * @history 2026-11-19 | 0.1.0 | Establish structural documentation and component responsibilities.
 */
public final class Loggers {

    private Loggers() {
    }

    public static Logger open(MessageCatalog catalog, Clock clock, Verbosity verbosity, PrintStream out, PrintStream err, boolean colors, boolean trace,
            Path directory, String application, String component) throws IOException {
        LogSink console = new ConsoleSink(out, err, verbosity, colors);
        LogSink persistent = new FileLogSink(directory, application, clock, trace);
        return new Logger(catalog, clock, component, persistent, console);
    }
}
