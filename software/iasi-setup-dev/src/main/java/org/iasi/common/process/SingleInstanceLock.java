package org.iasi.common.process;

import java.io.IOException;
import java.nio.channels.FileChannel;
import java.nio.channels.FileLock;
import java.nio.channels.OverlappingFileLockException;
import java.nio.file.Path;
import java.nio.file.StandardOpenOption;
import java.util.HashMap;
import java.util.Map;

/**
 * Owns an exclusive NIO instance lock independently of executable names and application policy.
 *
 * @author Javier G. Grandez
 * @since 0.1.0
 * @version 0.1.0
 * @history 2026-11-20 | 0.1.0 | Coordinate instances using a persistent lock file in the shared temporary directory.
 */
public final class SingleInstanceLock implements AutoCloseable {
    private static final String LOCK_SUFFIX = ".lock";

    // Keep one owner channel per path: closing competing channels can release POSIX locks.
    private static final Map<Path, SingleInstanceLock> OWNERS = new HashMap<>();

    private final Path        path;
    private final FileChannel channel;
    private final FileLock    lock;
    private boolean           closed;

    private SingleInstanceLock(Path path, FileChannel channel, FileLock lock) {
        this.path    = path;
        this.channel = channel;
        this.lock    = lock;
    }

    /**
     * Retains ownership internally until release is requested for the same name.
     *
     * @param name plain filename without the .lock suffix
     * @return true when acquired, false when another instance owns the lock
     * @throws IOException if access to the lock cannot be established
     */
    public static boolean tryAcquire(String name) throws IOException {
        return tryAcquire(Path.of(System.getProperty("java.io.tmpdir")), name);
    }

    public static boolean tryAcquire(Path temporaryDirectory, String name) throws IOException {
        try {
            acquire(temporaryDirectory, name);
            return true;
        } catch (BusyException exception) {
            return false;
        }
    }

    /**
     * Releases a retained owner without removing its persistent file.
     *
     * @param name plain filename used for acquisition
     * @throws IOException if release or channel closure fails
     */
    public static void release(String name) throws IOException {
        release(Path.of(System.getProperty("java.io.tmpdir")), name);
    }

    public static synchronized void release(Path temporaryDirectory, String name) throws IOException {
        checkName(name);
        Path path = temporaryDirectory.toRealPath().resolve(name + LOCK_SUFFIX);
        SingleInstanceLock owner = OWNERS.get(path);
        if (owner != null) owner.close();
    }

    public static SingleInstanceLock acquire(String name) throws IOException {
        return acquire(Path.of(System.getProperty("java.io.tmpdir")), name);
    }

    /**
     * Opens or creates the persistent lock without truncating it. Callers must retain
     * and close the returned owner; a pre-existing file is not evidence of contention.
     *
     * @param temporaryDirectory temporary namespace shared by the participating processes
     * @param name plain filename without the .lock suffix or directory components
     * @return owner of the exclusive lock and its channel
     * @throws BusyException if another owner holds the lock
     * @throws IOException if the file cannot be opened or locked
     * @throws IllegalArgumentException if the name contains a path or the lock suffix
     */
    public static synchronized SingleInstanceLock acquire(Path temporaryDirectory, String name) throws IOException {
        checkName(name);
        Path path = temporaryDirectory.toRealPath().resolve(name + LOCK_SUFFIX);
        if (OWNERS.containsKey(path)) throw new BusyException();
        FileChannel channel = FileChannel.open(path, StandardOpenOption.CREATE, StandardOpenOption.WRITE);
        try {
            FileLock lock = tryLock(channel);
            SingleInstanceLock owner = new SingleInstanceLock(path, channel, lock);
            OWNERS.put(path, owner);
            return owner;
        } catch (IOException | RuntimeException exception) {
            closeRejectedChannel(channel, exception);
            throw exception;
        }
    }

    private static void checkName(String name) {
        if (name == null || name.isBlank() || name.equals(".") || name.equals("..")
                || name.contains("/") || name.contains("\\") || name.toLowerCase(java.util.Locale.ROOT).endsWith(LOCK_SUFFIX))
            throw new IllegalArgumentException("Expected a plain lock name without its suffix");
    }

    private static FileLock tryLock(FileChannel channel) throws IOException {
        try {
            FileLock lock = channel.tryLock();
            if (lock == null) throw new BusyException();
            return lock;
        } catch (OverlappingFileLockException exception) {
            throw new BusyException();
        }
    }

    private static void closeRejectedChannel(FileChannel channel, Exception failure) {
        try {
            channel.close();
        } catch (IOException closeFailure) {
            failure.addSuppressed(closeFailure);
        }
    }

    public Path path() {
        return path;
    }

    /**
     * Releases the lock before closing its channel, retaining suppressed failures.
     * Repeated closure is harmless; the file is never removed or renamed.
     *
     * @throws IOException if release or channel closure fails
     */
    @Override
    public void close() throws IOException {
        synchronized (SingleInstanceLock.class) {
            if (closed) return;
            try (FileChannel ownedChannel = channel; FileLock ownedLock = lock) {
                // Reverse resource order releases FileLock before FileChannel.
            } finally {
                closed = true;
                OWNERS.remove(path, this);
            }
        }
    }

    /**
     * Distinguishes an active instance from I/O or permission failures during acquisition.
     *
     * @author Javier G. Grandez
     * @since 0.1.0
     * @version 0.1.0
     * @history 2026-11-20 | 0.1.0 | Represent lock contention without imposing process exit behavior.
     */
    public static final class BusyException extends IOException {
        private BusyException() {
            super("The instance lock is already held");
        }
    }
}
