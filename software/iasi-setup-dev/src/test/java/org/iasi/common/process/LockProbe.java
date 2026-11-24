package org.iasi.common.process;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import org.iasi.base.RC;

/**
 * Holds the production lock in an isolated test JVM until stdin signals controlled termination.
 *
 * @author Javier G. Grandez
 * @since 0.1.0
 * @version 0.1.0
 * @history 2026-11-20 | 0.1.0 | Provide deterministic IPC for concurrent ownership and crash-recovery tests.
 */
public final class LockProbe {
    public static void main(String[] args) throws Exception {
        try (var owner = SingleInstanceLock.acquire(args[1])) {
            if (args.length > 2) Files.writeString(Path.of(args[2]), "work started");
            System.out.println("LOCKED");
            System.out.flush();
            if (args[0].equals("hold")) System.in.read();
        } catch (SingleInstanceLock.BusyException exception) {
            System.out.println("BUSY");
            System.exit(RC.ERROR);
        } catch (IOException | SecurityException exception) {
            System.out.println("IO_ERROR");
            System.exit(RC.ERROR);
        }
    }
}
