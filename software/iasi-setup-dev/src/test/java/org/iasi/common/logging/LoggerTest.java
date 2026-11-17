package org.iasi.common.logging;

import org.iasi.base.Verbosity;

import static org.junit.jupiter.api.Assertions.*;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.PrintStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import org.iasi.common.i18n.MessageCatalog;
import org.junit.jupiter.api.Test;

/** Contratos del puerto común con adaptadores ajenos al backend de archivo. */
class LoggerTest {
    private static final Clock CLOCK = Clock.fixed(Instant.parse("2026-11-17T12:34:56Z"), ZoneOffset.UTC);
    private static final MessageDefinition MESSAGE = new Definition("TST01001", Severity.INFO, "event");

    /**
     * Comprueba sustitución del destino y distribución del mismo evento ya saneado.
     */
    @Test
    void alternateBackendsReceiveTheSameSanitizedEvent() throws IOException {
        RecordingSink persistent = new RecordingSink();
        RecordingSink console = new RecordingSink();
        try (Logger logger = logger(persistent, console)) {
            logger.emit(MESSAGE, "token=example-sensitive-value");
        }
        assertEquals(1, persistent.events.size());
        assertSame(persistent.events.getFirst(), console.events.getFirst());
        LogEvent event = persistent.events.getFirst();
        assertEquals("TST01001", event.code());
        assertEquals(CLOCK.instant(), event.timestamp().toInstant());
        assertEquals("independent-component", event.component());
        assertFalse(event.message().contains("example-sensitive-value"));
        assertTrue(persistent.closed && console.closed);
    }

    /**
     * Impide anunciar en consola un evento que el backend no ha podido persistir.
     */
    @Test
    void backendFailurePropagatesBeforeConsoleEmission() throws IOException {
        RecordingSink persistent = new RecordingSink();
        persistent.failWrite = true;
        RecordingSink console = new RecordingSink();
        try (Logger logger = logger(persistent, console)) {
            assertThrows(IOException.class, () -> logger.emit(MESSAGE, "example"));
        }
        assertTrue(console.events.isEmpty());
        assertTrue(persistent.closed && console.closed);
    }

    /**
     * Verifica liberación de ambos adaptadores y conservación de fallos
     * secundarios.
     */
    @Test
    void closeAttemptsBothDestinationsAndRetainsSuppressedFailures() {
        RecordingSink persistent = new RecordingSink();
        persistent.failClose = true;
        RecordingSink console = new RecordingSink();
        console.failClose = true;
        Logger logger = logger(persistent, console);
        IOException failure = assertThrows(IOException.class, logger::close);
        assertTrue(persistent.closed && console.closed);
        assertEquals(1, failure.getSuppressed().length);
    }

    /** El cierre del adaptador no debe apropiarse de stdout/stderr prestados. */
    @Test
    void consoleDoesNotCloseBorrowedStreams() {
        TrackingStream stream = new TrackingStream();
        PrintStream output = new PrintStream(stream);
        ConsoleSink sink = new ConsoleSink(output, output, Verbosity.NORMAL, false);
        sink.close();
        output.println("still-open");
        assertFalse(stream.closed);
        assertTrue(stream.toString().contains("still-open"));
    }

    /**
     * Evita reintroducir dependencias de dominio dentro de la infraestructura
     * reutilizable.
     */
    @Test
    void commonSourcesDoNotDependOnSetupDevOrLog4j() throws IOException {
        try (var files = Files.walk(Path.of("src/main/java/org/iasi/common"))) {
            for (Path file : files.filter(path -> path.toString().endsWith(".java")).toList()) {
                String text = Files.readString(file);
                assertFalse(text.contains("org.iasi.setupdev"), file.toString());
                assertFalse(text.contains("org.iasisetupdev"), file.toString());
                assertFalse(text.contains("import org.apache.logging"), file.toString());
                assertFalse(text.contains("iasi-setup-dev"), file.toString());
            }
        }
    }

    /**
     * Rechaza identificadores mal formados en la frontera común, antes de los
     * adaptadores.
     */
    @Test
    void invalidMessageCodeCannotReachDestinations() throws IOException {
        RecordingSink persistent = new RecordingSink();
        RecordingSink console = new RecordingSink();
        try (Logger logger = logger(persistent, console)) {
            assertThrows(IllegalArgumentException.class, () -> logger.emit(new Definition("bad", Severity.INFO, "event"), "example"));
        }
        assertTrue(persistent.events.isEmpty() && console.events.isEmpty());
    }

    /**
     * Compone una aplicación de prueba con catálogo propio y dos adaptadores
     * inyectados.
     */
    private Logger logger(LogSink persistent, LogSink console) {
        return new Logger(new MessageCatalog("org.iasi.common.logging.fixture", Locale.ROOT), CLOCK, "independent-component", persistent, console);
    }

    /**
     * La representación conserva sus garantías aunque se construya fuera de la
     * fachada.
     */
    @Test
    void directlyConstructedEventsCannotInjectControlsOrSecrets() {
        LogEvent event = new LogEvent(java.time.ZonedDateTime.now(CLOCK), "TST01002", Severity.INFO, "component\nforged",
                "token=example-sensitive-value\u001b[31m");
        assertFalse(event.component().contains("\n"));
        assertFalse(event.message().contains("example-sensitive-value"));
        assertFalse(event.message().contains("\u001b"));
    }

    private record Definition(String code, Severity severity, String key) implements MessageDefinition {
    }

    private static final class RecordingSink implements LogSink {
        private final List<LogEvent> events = new ArrayList<>();
        private boolean closed;
        private boolean failWrite;
        private boolean failClose;

        /** Registra el evento original o simula un fallo del backend alternativo. */
        @Override
        public void write(LogEvent event) throws IOException {
            if (failWrite) throw new IOException("Synthetic backend failure");
            events.add(event);
        }

        /** Permite comprobar propiedad de recursos y errores de cierre del contrato. */
        @Override
        public void close() throws IOException {
            closed = true;
            if (failClose) throw new IOException("Synthetic close failure");
        }
    }

    private static final class TrackingStream extends ByteArrayOutputStream {
        private boolean closed;

        /** Detecta un cierre accidental de un stream que pertenece al consumidor. */
        @Override
        public void close() throws IOException {
            closed = true;
            super.close();
        }
    }
}
