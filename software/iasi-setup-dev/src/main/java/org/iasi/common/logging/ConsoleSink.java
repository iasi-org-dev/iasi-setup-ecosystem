package org.iasi.common.logging;

import org.iasi.base.Verbosity;

import java.io.PrintStream;
import java.time.format.DateTimeFormatter;

/**
 * Representación de consola con filtrado local, colores opcionales y errores en
 * stderr.
 */
public final class ConsoleSink implements LogSink {
    private static final DateTimeFormatter TIME = DateTimeFormatter.ofPattern("HH:mm:ss");
    private final PrintStream out;
    private final PrintStream err;
    private final Verbosity verbosity;
    private final boolean colors;

    /**
     * Recibe streams prestados y una decisión de soporte ANSI tomada por el
     * ejecutable.
     */
    public ConsoleSink(PrintStream out, PrintStream err, Verbosity verbosity, boolean colors) {
        this.out = out;
        this.err = err;
        this.verbosity = verbosity;
        this.colors = colors;
    }

    /**
     * Filtra solo la consola; utiliza el instante original y conserva el formato
     * IASI.
     */
    @Override
    public void write(LogEvent event) {
        if (!includes(event.severity())) return;
        String line = event.timestamp().format(TIME) + " - " + event.code() + " - " + event.message();
        if (colors && !event.severity().color().isEmpty()) line = "\u001b[" + event.severity().color() + "m" + line + "\u001b[0m";
        PrintStream destination = event.severity() == Severity.ERROR ? err : out;
        destination.println(line);
    }

    /** No cierra stdout/stderr: pertenecen al proceso, no al destino de logging. */
    @Override
    public void close() {
        out.flush();
        err.flush();
    }

    /**
     * Aplica el filtro de presentación en common, sin acoplar los valores base a
     * las severidades de logging.
     */
    private boolean includes(Severity severity) {
        if (severity == Severity.ERROR) return true;
        if (verbosity == Verbosity.SILENT) return false;
        if (severity == Severity.TRACE) return verbosity == Verbosity.VERY_VERBOSE;
        if (severity == Severity.DEBUG) return verbosity == Verbosity.VERBOSE || verbosity == Verbosity.VERY_VERBOSE;
        return true;
    }
}
