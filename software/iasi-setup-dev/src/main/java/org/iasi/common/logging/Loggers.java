package org.iasi.common.logging;

import org.iasi.base.Verbosity;

import java.io.IOException;
import java.io.PrintStream;
import java.nio.file.Path;
import java.time.Clock;
import org.iasi.common.i18n.MessageCatalog;

/**
 * Punto de composición del backend predeterminado, aislado de la lógica de las
 * aplicaciones.
 */
public final class Loggers {
    /** Clase de utilidad; la configuración predeterminada se crea mediante open. */
    private Loggers() {
    }

    /**
     * Abre el backend actual. Una futura selección de Log4j se concentra en este
     * punto.
     */
    public static Logger open(MessageCatalog catalog, Clock clock, Verbosity verbosity, PrintStream out, PrintStream err, boolean colors, boolean trace,
            Path directory, String application, String component) throws IOException {
        LogSink console = new ConsoleSink(out, err, verbosity, colors);
        LogSink persistent = new FileLogSink(directory, application, clock, trace);
        return new Logger(catalog, clock, component, persistent, console);
    }
}
