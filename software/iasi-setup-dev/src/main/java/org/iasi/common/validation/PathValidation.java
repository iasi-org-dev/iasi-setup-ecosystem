package org.iasi.common.validation;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;

/**
 * Checks filesystem object types and prepares missing paths when their policy permits creation.
 *
 * @author Javier G. Grandez
 * @since 0.1.0
 * @version 0.1.0
 * @history 2026-11-19 | 0.1.0 | Establish structural documentation and component responsibilities.
 */
public final class PathValidation {
    private PathValidation() {
    }

    public static void check(Path path, boolean directory, boolean required) {
        if (!Files.exists(path)) {
            if (required) throw new ValueConstraintException("Path must exist");
            return;
        }
        boolean valid = directory ? Files.isDirectory(path) : Files.isRegularFile(path);
        if (!valid) throw new ValueConstraintException("Unexpected path type");
    }

    /**
     * Creates only missing paths whose policy permits creation; callers must check constraints first.
     * @throws IOException if the filesystem cannot create the requested path
     */
    public static void prepare(Path path, boolean directory, boolean required) throws IOException {
        if (required || Files.exists(path)) return;
        if (directory) Files.createDirectories(path);
        else Files.createFile(path);
    }
}
