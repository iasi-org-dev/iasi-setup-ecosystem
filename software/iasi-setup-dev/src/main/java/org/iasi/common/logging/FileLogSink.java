package org.iasi.common.logging;

import java.io.BufferedWriter;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardOpenOption;
import java.time.Clock;
import java.util.UUID;

/**
 * Destino UTF-8 por ejecución; independiente de la verbosidad elegida para
 * consola.
 */
public final class FileLogSink implements LogSink {
    private final BufferedWriter writer;
    private final Path file;
    private final boolean trace;

    /**
     * Crea un archivo exclusivo; el prefijo identifica la aplicación sin acoplar
     * esta clase a ella.
     */
    public FileLogSink(Path directory, String application, Clock clock, boolean trace) throws IOException {
        if (!application.matches("[A-Za-z0-9._-]+")) throw new IllegalArgumentException("Invalid application identifier");
        Files.createDirectories(directory);
        this.trace = trace;
        file = directory.resolve(application + "-" + clock.millis() + "-" + UUID.randomUUID() + ".log");
        writer = Files.newBufferedWriter(file, StandardCharsets.UTF_8, StandardOpenOption.CREATE_NEW);
    }

    /**
     * Persiste metadatos sin ANSI y fuerza la escritura antes de que se anuncie el
     * evento en consola.
     */
    @Override
    public void write(LogEvent event) throws IOException {
        if (event.severity() == Severity.TRACE && !trace) return;
        writer.write(event.timestamp() + " - " + event.code() + " - " + event.severity() + " - " + event.component() + " - " + event.message());
        writer.newLine();
        writer.flush();
    }

    /**
     * Ruta creada por este adaptador, útil para inspección sin exponerla en la
     * fachada.
     */
    public Path file() {
        return file;
    }

    /** Cierra el archivo propio y propaga errores de persistencia. */
    @Override
    public void close() throws IOException {
        writer.close();
    }
}
