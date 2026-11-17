package org.iasi.common.logging;

import org.iasi.base.Verbosity;

import java.io.IOException;
import java.io.PrintStream;
import java.time.Clock;
import java.time.ZonedDateTime;
import org.iasi.common.i18n.MessageCatalog;

/**
 * Fachada común: localiza y sanea una vez; los adaptadores reciben el mismo
 * evento. No es thread-safe.
 */
public final class Logger implements AutoCloseable {
    private final MessageCatalog catalog;
    private final Clock clock;
    private final String component;
    private final LogSink persistent;
    private final LogSink console;

    /**
     * Inyecta destinos; un adaptador Log4j puede sustituir persistencia sin cambiar
     * a los consumidores.
     */
    public Logger(MessageCatalog catalog, Clock clock, String component, LogSink persistent, LogSink console) {
        this.catalog = catalog;
        this.clock = clock;
        this.component = component;
        this.persistent = persistent;
        this.console = console;
    }

    /**
     * Emite un evento atómico. Un fallo de persistencia se propaga antes de
     * anunciarlo en consola.
     */
    public void emit(MessageDefinition definition, Object... arguments) throws IOException {
        ZonedDateTime time = ZonedDateTime.now(clock);
        String text = catalog.text(definition.key(), arguments);
        LogEvent event = new LogEvent(time, definition.code(), definition.severity(), component, text);
        persistent.write(event);
        console.write(event);
    }

    /**
     * Diagnóstico previo al arranque, sin abrir archivos ni requerir un backend
     * disponible.
     */
    public static void earlyError(MessageCatalog catalog, PrintStream err, Clock clock, MessageDefinition definition, Object... arguments) {
        String text = catalog.text(definition.key(), arguments);
        LogEvent event = new LogEvent(ZonedDateTime.now(clock), definition.code(), definition.severity(), "bootstrap", text);
        new ConsoleSink(err, err, Verbosity.SILENT, false).write(event);
    }

    /**
     * Intenta cerrar ambos destinos incluso si uno falla, conservando excepciones
     * suprimidas.
     */
    @Override
    public void close() throws IOException {
        try (LogSink first = persistent; LogSink second = console) {
            // El cierre automático conserva también cualquier segundo fallo de liberación.
        }
    }
}
