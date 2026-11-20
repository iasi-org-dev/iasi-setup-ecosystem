package org.iasi.common.logging;

import java.io.BufferedWriter;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardOpenOption;
import java.time.Clock;
import java.time.ZonedDateTime;
import java.time.format.DateTimeFormatter;

/**
 * Persists UTF-8 events without console colors in an exclusively created execution log.
 *
 * @author Javier G. Grandez
 * @since 0.1.0
 * @version 0.1.0
 * @history 2026-11-19 | 0.1.0 | Establish structural documentation and component responsibilities.
 */
public final class FileLogSink implements LogSink {
    private static final DateTimeFormatter FILE_TIME = DateTimeFormatter.ofPattern("yyyyMMdd-HHmmss");
    private final BufferedWriter writer;
    private final Path file;
    private final boolean trace;

    /**
     * Requires a previously prepared directory and exclusively creates the execution log without overwriting an existing file.
     * @throws IOException if creation fails, including a filename collision
     */
    public FileLogSink(Path directory, String application, Clock clock, boolean trace) throws IOException {
        if (!application.matches("[A-Za-z0-9._-]+")) throw new IllegalArgumentException("Invalid application identifier");
        this.trace = trace;
        file = directory.resolve(application + "-" + ZonedDateTime.now(clock).format(FILE_TIME) + ".log");
        writer = Files.newBufferedWriter(file, StandardCharsets.UTF_8, StandardOpenOption.CREATE_NEW);
    }

    @Override
    public void write(LogEvent event) throws IOException {
        if (event.severity() == Severity.TRACE && !trace) return;
        writer.write(event.timestamp() + " - " + event.code() + " - " + event.severity() + " - " + event.component() + " - " + event.message());
        writer.newLine();
        writer.flush();
    }

    public Path file() {
        return file;
    }

    @Override
    public void close() throws IOException {
        writer.close();
    }
}
