package org.iasi.setupdev;

import static org.junit.jupiter.api.Assertions.*;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.PrintStream;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.HashSet;
import java.util.Locale;
import java.util.ResourceBundle;
import java.util.Set;
import java.util.regex.Pattern;
import org.iasi.common.i18n.MessageCatalog;
import org.iasi.common.logging.ConsoleSink;
import org.iasi.common.logging.FileLogSink;
import org.iasi.common.logging.Logger;
import org.iasi.common.logging.Severity;
import org.iasi.base.Verbosity;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

class MessagesTest {
    static final Clock CLOCK = Clock.fixed(Instant.parse("2026-11-17T12:34:56Z"), ZoneOffset.UTC);
    @TempDir
    Path directory;
    private Path lastLogFile;

    /**
     * Contrasta formato, colores, severidades persistidas y enrutamiento de errores
     * a stderr.
     */
    @Test
    void exactFormatColorsSeveritiesAndRouting() throws IOException {
        var out = new ByteArrayOutputStream();
        var err = new ByteArrayOutputStream();
        Path log;
        try (Logger messages = messages(Verbosity.NORMAL, out, err, true, false)) {
            messages.emit(Event.START, "platform");
            messages.emit(Event.WARNING, "example");
            messages.emit(Event.UNAVAILABLE, "create");
            log = lastLogFile;
        }
        assertTrue(out.toString(StandardCharsets.UTF_8).startsWith("12:34:56 - SYS01001 - Starting platform." + System.lineSeparator()));
        assertTrue(out.toString(StandardCharsets.UTF_8).contains("\u001b[33m12:34:56 - SYS01008 - "));
        assertTrue(err.toString(StandardCharsets.UTF_8).startsWith("\u001b[31m12:34:56 - CLI01002 - "));
        String contents = Files.readString(log);
        assertTrue(contents.contains("2026-11-17T12:34:56Z - CLI01002 - ERROR - launcher"));
        assertTrue(contents.contains("WARNING"));
        assertFalse(contents.contains("\u001b"));
    }

    /**
     * Repite los contratos de visibilidad y persistencia bajo cada modo de consola.
     */
    @Test
    void allConsoleModesPreserveLogEvents() throws IOException {
        for (Verbosity verbosity : Verbosity.values())
            verifyMode(verbosity);
    }

    /** Compara cada evento del catálogo con sus filtros de consola y archivo. */
    private void verifyMode(Verbosity verbosity) throws IOException {
        var out = new ByteArrayOutputStream();
        var err = new ByteArrayOutputStream();
        Path log;
        try (Logger messages = messages(verbosity, out, err, false, false)) {
            for (Event event : Event.values())
                messages.emit(event, "a", "b", "c", "d", "e");
            log = lastLogFile;
        }
        String console = out.toString(StandardCharsets.UTF_8) + err.toString(StandardCharsets.UTF_8);
        String persisted = Files.readString(log);
        for (Event event : Event.values()) {
            assertEquals(visible(verbosity, event.severity()), console.contains(event.code()), event.code());
            assertEquals(event.severity() != Severity.TRACE, persisted.contains(event.code()));
        }
        assertFalse(console.contains("\u001b"));
    }

    /** Verifica TRACE opcional y archivos distintos aun con un reloj congelado. */
    @Test
    void traceLoggingIsExplicitAndFilenamesAreCollisionProtected() throws IOException {
        Path first;
        try (Logger messages = messages(Verbosity.NORMAL, new ByteArrayOutputStream(), new ByteArrayOutputStream(), false, true)) {
            first = lastLogFile;
            messages.emit(Event.RUNTIME, "25", "vendor");
        }
        try (Logger messages = messages(Verbosity.NORMAL, new ByteArrayOutputStream(), new ByteArrayOutputStream(), false, false)) {
            assertNotEquals(first, lastLogFile);
        }
        assertTrue(Files.readString(first).contains("TRACE"));
    }

    /**
     * Detecta códigos duplicados o inválidos y diferencias de parámetros entre
     * traducciones.
     */
    @Test
    void catalogsHaveStableUniqueCodesAndCompatibleParameters() {
        Set<String> codes = new HashSet<>();
        ResourceBundle english = ResourceBundle.getBundle("org.iasi.setupdev.messages", Locale.ROOT);
        ResourceBundle spanish = ResourceBundle.getBundle("org.iasi.setupdev.messages", Locale.forLanguageTag("es"));
        for (Event event : Event.values()) {
            assertTrue(event.code().matches("[A-Z]{3}[0-9]{2}[0-9]{3}"));
            assertTrue(codes.add(event.code()));
            assertEquals(parameters(english.getString(event.key())), parameters(spanish.getString(event.key())));
        }
        assertNotEquals(new MessageCatalog("org.iasi.setupdev.messages", Locale.ENGLISH).text("start", "x"),
                new MessageCatalog("org.iasi.setupdev.messages", Locale.forLanguageTag("es")).text("start", "x"));
        assertEquals(new MessageCatalog("org.iasi.setupdev.messages", Locale.ROOT).text("start", "x"),
                new MessageCatalog("org.iasi.setupdev.messages", Locale.JAPANESE).text("start", "x"));
    }

    /**
     * Comprueba saneado de credenciales y controles antes de consola y
     * persistencia.
     */
    @Test
    void redactionAndControlSanitizationApplyBeforeBothDestinations() throws IOException {
        var out = new ByteArrayOutputStream();
        Path log;
        try (Logger messages = messages(Verbosity.NORMAL, out, new ByteArrayOutputStream(), false, false)) {
            messages.emit(Event.START, "token=example-value password=\"two words\" Bearer example-auth https://user:example-password@host\nforged\u001b[31m");
            log = lastLogFile;
        }
        String combined = out.toString(StandardCharsets.UTF_8) + Files.readString(log);
        assertFalse(combined.contains("example-value"));
        assertFalse(combined.contains("two words"));
        assertFalse(combined.contains("example-auth"));
        assertFalse(combined.contains("example-password"));
        assertFalse(combined.contains("\u001b"));
        assertEquals(1, Files.readAllLines(log).size());
    }

    /**
     * Extrae marcadores de interpolación para contrastar catálogos sin comparar sus
     * textos traducidos.
     */
    private Set<String> parameters(String template) {
        Set<String> values = new HashSet<>();
        Pattern.compile("\\{[0-9]+}").matcher(template).results().forEach(match -> values.add(match.group()));
        return values;
    }

    /**
     * Compone destinos reales aislados para las pruebas de integración del catálogo
     * del launcher.
     */
    private Logger messages(Verbosity verbosity, ByteArrayOutputStream out, ByteArrayOutputStream err, boolean colors, boolean trace) throws IOException {
        FileLogSink file = new FileLogSink(directory, "iasi-setup-dev", CLOCK, trace);
        lastLogFile = file.file();
        ConsoleSink console = new ConsoleSink(new PrintStream(out, true, StandardCharsets.UTF_8), new PrintStream(err, true, StandardCharsets.UTF_8), verbosity,
                colors);
        return new Logger(new MessageCatalog("org.iasi.setupdev.messages", Locale.ENGLISH), CLOCK, "launcher", file, console);
    }
    /**
     * Oráculo de visibilidad independiente de la implementación del destino de
     * consola.
     */
    private boolean visible(Verbosity verbosity, Severity severity) {
        java.util.Set<Severity> visible = switch (verbosity) {
            case NORMAL -> java.util.Set.of(Severity.INFO, Severity.SUCCESS, Severity.WARNING, Severity.ERROR);
            case VERBOSE -> java.util.EnumSet.complementOf(java.util.EnumSet.of(Severity.TRACE));
            case VERY_VERBOSE -> java.util.EnumSet.allOf(Severity.class);
            case SILENT -> java.util.Set.of(Severity.ERROR);
        };
        return visible.contains(severity);
    }

}
