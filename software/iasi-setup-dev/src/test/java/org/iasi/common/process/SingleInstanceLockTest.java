package org.iasi.common.process;

import static org.junit.jupiter.api.Assertions.*;

import java.io.IOException;
import java.nio.channels.FileChannel;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardOpenOption;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

/**
 * Checks persistent lock ownership, same-JVM contention and named lock independence.
 *
 * @author Javier G. Grandez
 * @since 0.1.0
 * @version 0.1.0
 * @history 2026-11-20 | 0.1.0 | Exercise the reusable lock lifecycle without application termination policy.
 */
class SingleInstanceLockTest {
    @TempDir
    Path directory;

    @Test
    void booleanAcquisitionRetainsOwnershipUntilExplicitRelease() throws IOException {
        assertTrue(SingleInstanceLock.tryAcquire(directory, "boolean-owner"));
        try {
            assertFalse(SingleInstanceLock.tryAcquire(directory, "boolean-owner"));
            assertThrows(IOException.class,
                    () -> SingleInstanceLock.tryAcquire(directory.resolve("missing"), "boolean-owner"));
        } finally {
            SingleInstanceLock.release(directory, "boolean-owner");
        }
        assertTrue(SingleInstanceLock.tryAcquire(directory, "boolean-owner"));
        SingleInstanceLock.release(directory, "boolean-owner");
        SingleInstanceLock.release(directory, "boolean-owner");
        assertTrue(Files.exists(directory.resolve("boolean-owner.lock")));
    }

    @Test
    void preservesExistingFileAndAllowsReacquisitionAfterClose() throws IOException {
        Path file = directory.resolve("coordinator.lock");
        Files.writeString(file, "persistent marker");
        SingleInstanceLock owner = SingleInstanceLock.acquire(directory, "coordinator");
        assertEquals(file.toRealPath(), owner.path());
        assertThrows(SingleInstanceLock.BusyException.class, () -> SingleInstanceLock.acquire(directory, "coordinator"));
        owner.close();
        owner.close();
        assertEquals("persistent marker", Files.readString(file));
        try (var next = SingleInstanceLock.acquire(directory, "coordinator")) {
            assertEquals(file.toRealPath(), next.path());
        }
        assertTrue(Files.exists(file));
    }

    @Test
    void supportsDifferentNamesInTheSameTemporaryNamespace() throws IOException {
        try (var first = SingleInstanceLock.acquire(directory, "first");
             var second = SingleInstanceLock.acquire(directory, "second")) {
            assertNotEquals(first.path(), second.path());
        }
    }

    @Test
    void translatesOverlappingFileLocksIntoContention() throws IOException {
        Path file = directory.resolve("coordinator.lock");
        try (var channel = FileChannel.open(file, StandardOpenOption.CREATE, StandardOpenOption.WRITE);
             var ignored = channel.lock()) {
            assertThrows(SingleInstanceLock.BusyException.class, () -> SingleInstanceLock.acquire(directory, "coordinator"));
        }
    }

    @Test
    void rejectsUnusableRootsAndInvalidNames() throws IOException {
        Path file = Files.createFile(directory.resolve("not-a-directory"));
        assertThrows(IOException.class, () -> SingleInstanceLock.acquire(file, "coordinator"));
        assertThrows(IOException.class, () -> SingleInstanceLock.acquire(directory.resolve("missing"), "coordinator"));
        for (String name : new String[]{"", "../outside", "other/name", "other\\name", "iasi.lock"})
            assertThrows(IllegalArgumentException.class, () -> SingleInstanceLock.acquire(directory, name));
    }
}
