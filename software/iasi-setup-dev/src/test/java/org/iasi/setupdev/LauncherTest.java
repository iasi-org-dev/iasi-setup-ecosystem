package org.iasi.setupdev;

import static org.junit.jupiter.api.Assertions.*;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.PrintStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Locale;
import java.util.function.Supplier;
import org.iasi.common.platform.Platform;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

class LauncherTest {
    @TempDir
    Path cwd;
    private final ByteArrayOutputStream out = new ByteArrayOutputStream();
    private final ByteArrayOutputStream err = new ByteArrayOutputStream();

    /**
     * Verifica todos los contextos de ayuda con fuentes inexistentes y un detector
     * que falla si se invoca.
     */
    @Test
    void contextualHelpNeverLoadsConfigurationOrProbesPlatform() throws IOException {
        for (String input : new String[]{"help", "workflow help", "create -h", "workflow release -h", "platform -h"}) {
            String[] words = (input + " --config missing.toml --logs do-not-create").split(" ");
            assertEquals(0, run(() -> {
                throw new AssertionError("Help probed host");
            }, words));
        }
        try (var files = Files.list(cwd)) {
            assertEquals(0, files.count());
        }
        assertTrue(out.toString().contains("Machine creation is unavailable"));
        assertTrue(out.toString().contains("No promotion or workflow execution"));
        for (Command command : Command.values())
            assertTrue(out.toString().contains(command.syntax()));
    }

    /** Impide que una acción reservada consulte el host o anuncie éxito. */
    @Test
    void unavailableActionsNeverPretendSuccess() {
        assertEquals(2, run(() -> {
            throw new AssertionError("Unavailable action probed host");
        }, "create"));
        assertTrue(err.toString().contains("CLI01002"));
        assertFalse(out.toString().contains("SYS01005"));
    }

    /**
     * Comprueba diagnóstico estructurado y salida de error para una familia
     * desconocida.
     */
    @Test
    void reportsKnownAndUnknownPlatforms() {
        assertEquals(0, run(() -> PlatformTest.detect("Linux"), "platform", "-V"));
        assertTrue(out.toString().contains("s390x"));
        assertTrue(out.toString().contains("test-vendor"));
        out.reset();
        assertEquals(3, run(() -> PlatformTest.detect("Plan 9"), "platform", "-s"));
        assertEquals("", out.toString());
        assertTrue(err.toString().contains("SYS01006"));
    }

    /**
     * Distingue el filtro de consola de la conservación de DEBUG y metadatos en el
     * archivo.
     */
    @Test
    void silentCliOverridesExternalVerboseAndKeepsLog() throws IOException {
        Files.writeString(cwd.resolve("instance.toml"), "verbose=true\nlogs='audit'\n");
        assertEquals(0, run(() -> PlatformTest.detect("Windows 11"), "platform", "--config", "instance.toml", "-v", "-s"));
        assertEquals("", out.toString());
        try (var logs = Files.list(cwd.resolve("audit"))) {
            String contents = Files.readString(logs.findFirst().orElseThrow());
            assertTrue(contents.contains("DEBUG"));
            assertTrue(contents.contains("force=false"));
        }
    }

    /**
     * Comprueba que una configuración inválida no deja destinos de logging creados
     * parcialmente.
     */
    @Test
    void configFailureDoesNotPartiallyCreateLogDirectories() throws IOException {
        Files.writeString(cwd.resolve("instance.toml"), "logs='must-not-exist'\nforce=true\n");
        assertEquals(2, run(() -> PlatformTest.detect("Linux"), "platform", "--config", "instance.toml"));
        assertFalse(Files.exists(cwd.resolve("must-not-exist")));
        assertTrue(err.toString().contains("CLI01001"));
    }

    /** Exige error visible si el usuario selecciona un archivo que no existe. */
    @Test
    void missingExplicitConfigFailsWithoutUsingDefaultsSilently() {
        assertEquals(1, run(() -> PlatformTest.detect("Linux"), "platform", "--config", "missing.toml"));
        assertTrue(err.toString().contains("SYS01009"));
    }

    /**
     * Verifica que un fallo de acceso conserva diagnóstico y código no cero incluso
     * con -s.
     */
    @Test
    void logFailureIsVisibleInSilentMode() throws IOException {
        Path file = Files.writeString(cwd.resolve("file"), "occupied");
        assertEquals(1, run(() -> PlatformTest.detect("Linux"), "platform", "-s", "--logs", file.toString()));
        assertTrue(err.toString().contains("SYS01009"));
        assertFalse(out.toString().contains("SYS01005"));
    }

    /** Asegura que el rechazo del comando ocurre antes de abrir el log. */
    @Test
    void invalidCommandHasNoFilesystemEffects() throws IOException {
        assertEquals(2, run(() -> PlatformTest.detect("Linux"), "help", "workflow"));
        try (var files = Files.list(cwd)) {
            assertEquals(0, files.count());
        }
    }

    /** Ejecuta el launcher con streams, reloj y detector aislados del host real. */
    private int run(Supplier<Platform> detector, String... arguments) {
        return Main.run(arguments, cwd, new PrintStream(out), new PrintStream(err), Locale.ENGLISH, MessagesTest.CLOCK, false, detector);
    }
}
