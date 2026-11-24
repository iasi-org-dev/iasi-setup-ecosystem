package org.iasi.common.process;

import static org.junit.jupiter.api.Assertions.*;

import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.Duration;
import java.util.concurrent.TimeUnit;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

/**
 * Checks real JVM exclusion, rejection without work and operating-system recovery after process death.
 *
 * @author Javier G. Grandez
 * @since 0.1.0
 * @version 0.1.0
 * @history 2026-11-20 | 0.1.0 | Exercise process-level locking with deterministic readiness and termination signals.
 */
class SingleInstanceProcessTest {
    @TempDir
    Path temporary;

    @Test
    void rejectsConcurrentJvmAndReacquiresWithoutDeletingLock() throws Exception {
        Path sentinel = temporary.resolve("iasi/keep.txt");
        Files.createDirectories(sentinel.getParent());
        Files.writeString(sentinel, "active resources");
        Process owner = start("hold", temporary, temporary.resolve("owner-work"));
        try {
            awaitOwner(owner);
            assertResult(start("try", temporary, temporary.resolve("rejected-work")), 16, "BUSY");
            assertFalse(Files.exists(temporary.resolve("rejected-work")));
            assertEquals("active resources", Files.readString(sentinel));
            assertTrue(owner.isAlive());
            owner.getOutputStream().write('\n');
            owner.getOutputStream().flush();
            assertTrue(owner.waitFor(10, TimeUnit.SECONDS));
            assertEquals(0, owner.exitValue());
            assertTrue(Files.exists(temporary.resolve("iasi.lock")));
            assertResult(start("try", temporary, temporary.resolve("next-work")), 0, "LOCKED");
        } finally {
            owner.destroyForcibly();
            owner.waitFor(10, TimeUnit.SECONDS);
        }
    }

    @Test
    void recoversImmediatelyAfterOwnerIsKilled() throws Exception {
        Process owner = start("hold", temporary, temporary.resolve("owner-work"));
        try {
            awaitOwner(owner);
            owner.destroyForcibly();
            assertTrue(owner.waitFor(10, TimeUnit.SECONDS));
            assertTrue(Files.exists(temporary.resolve("iasi.lock")));
            assertResult(start("try", temporary, temporary.resolve("recovery-work")), 0, "LOCKED");
        } finally {
            owner.destroyForcibly();
        }
    }

    @Test
    void cannotStartWorkWhenLockFileCannotBeOpened() throws Exception {
        Files.createDirectory(temporary.resolve("iasi.lock"));
        assertResult(start("try", temporary, temporary.resolve("forbidden-work")), 16, "IO_ERROR");
        assertFalse(Files.exists(temporary.resolve("forbidden-work")));
    }

    private Process start(String mode, Path directory, Path work) throws Exception {
        Path java = Path.of(System.getProperty("java.home"), "bin", "java");
        return new ProcessBuilder(java.toString(), "-Djava.io.tmpdir=" + directory, "-cp", System.getProperty("java.class.path"),
                LockProbe.class.getName(), mode, "iasi", work.toString()).redirectErrorStream(true).start();
    }

    private void awaitOwner(Process owner) {
        var reader = new BufferedReader(new InputStreamReader(owner.getInputStream()));
        assertTimeoutPreemptively(Duration.ofSeconds(10), () -> assertEquals("LOCKED", reader.readLine()));
    }

    private void assertResult(Process process, int rc, String output) throws Exception {
        try {
            assertTrue(process.waitFor(10, TimeUnit.SECONDS));
            String actual = new String(process.getInputStream().readAllBytes()).strip();
            assertEquals(rc, process.exitValue(), actual);
            assertEquals(output, actual);
        } finally {
            process.destroyForcibly();
        }
    }
}
