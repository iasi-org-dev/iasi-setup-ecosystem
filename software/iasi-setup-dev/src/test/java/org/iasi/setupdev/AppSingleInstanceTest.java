package org.iasi.setupdev;

import static org.junit.jupiter.api.Assertions.*;

import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.Duration;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.TimeUnit;
import org.iasi.common.process.LockProbe;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

/**
 * Verifies application lock diagnostics and exclusion before configuration or directory preparation.
 *
 * @author Javier G. Grandez
 * @since 0.1.0
 * @version 0.1.0
 * @history 2026-11-20 | 0.1.0 | Cover rejected startup and controlled-error recovery without bypasses in the production launcher.
 */
class AppSingleInstanceTest {
    @TempDir
    Path temporary;

    @Test
    void busyApplicationDoesNotReadConfigurationOrChangeActiveResources() throws Exception {
        Path sentinel = temporary.resolve("iasi/active.txt");
        Files.createDirectories(sentinel.getParent());
        Files.writeString(sentinel, "keep");
        Process owner = start(LockProbe.class, "hold", "iasi");
        try {
            var ready = new BufferedReader(new InputStreamReader(owner.getInputStream()));
            assertTimeoutPreemptively(Duration.ofSeconds(10), () -> assertEquals("LOCKED", ready.readLine()));
            String message = result(start(InstanceLockEntryPoint.class, "--config", "missing.toml", "--logs", temporary.resolve("new-logs").toString()), 16);
            assertTrue(message.contains("Another IASI coordinator instance is already running."), message);
            assertFalse(message.contains("specified by --config"), message);
            assertFalse(Files.exists(temporary.resolve("new-logs")));
            assertEquals("keep", Files.readString(sentinel));
            assertTrue(owner.isAlive());
        } finally {
            owner.getOutputStream().close();
            if (!owner.waitFor(10, TimeUnit.SECONDS)) owner.destroyForcibly();
        }
    }

    @Test
    void reportsIoFailureSeparatelyWithoutStartingConfiguration() throws Exception {
        Files.createDirectory(temporary.resolve("iasi.lock"));
        String message = result(start(InstanceLockEntryPoint.class, "--logs", temporary.resolve("new-logs").toString()), 16);
        assertTrue(message.contains("single-instance lock cannot be opened or acquired"), message);
        assertFalse(message.contains("already running"), message);
        assertFalse(Files.exists(temporary.resolve("new-logs")));
    }

    @Test
    void releasesOwnershipWhenInitializationTerminatesWithAnError() throws Exception {
        String message = result(start(InstanceLockEntryPoint.class, "--config", "missing.toml"), 16);
        assertTrue(message.contains("specified by --config does not exist"), message);
        assertTrue(Files.isRegularFile(temporary.resolve("iasi.lock")));
        assertEquals("LOCKED", result(start(LockProbe.class, "try", "iasi"), 0).strip());
    }

    private Process start(Class<?> entryPoint, String... arguments) throws Exception {
        var command = new ArrayList<>(List.of(Path.of(System.getProperty("java.home"), "bin", "java").toString(),
                "-Djava.io.tmpdir=" + temporary, "-Duser.language=en", "-cp", System.getProperty("java.class.path"), entryPoint.getName()));
        command.addAll(List.of(arguments));
        return new ProcessBuilder(command).directory(temporary.toFile()).redirectErrorStream(true).start();
    }

    private String result(Process process, int expected) throws Exception {
        try {
            assertTrue(process.waitFor(10, TimeUnit.SECONDS));
            String output = new String(process.getInputStream().readAllBytes());
            assertEquals(expected, process.exitValue(), output);
            return output;
        } finally {
            process.destroyForcibly();
        }
    }
}
