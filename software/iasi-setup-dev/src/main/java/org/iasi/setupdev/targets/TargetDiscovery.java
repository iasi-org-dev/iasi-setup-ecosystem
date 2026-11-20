package org.iasi.setupdev.targets;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Comparator;
import java.util.List;

/**
 * Discovers immediate machine directories with a direct configuration-directory marker,
 * without reading configuration contents or interpreting selection patterns.
 *
 * @author Javier G. Grandez
 * @since 0.1.0
 * @version 0.1.0
 * @history 2026-11-19 | 0.1.0 | Establish structural documentation and component responsibilities.
 * @history 2026-11-20 | 0.1.0 | Require a direct configuration-directory marker for machine candidates.
 */
public final class TargetDiscovery {
    public static final String MACHINE_CONFIG_DIRECTORY = "config-data";

    public List<Path> discover(Path definitions) throws IOException {
        try (var entries = Files.list(definitions)) {
            return entries.filter(this::isMachineCandidate)
                    .sorted(Comparator.comparing(path -> path.getFileName().toString()))
                    .toList();
        }
    }

    private boolean isMachineCandidate(Path candidate) {
        return Files.isDirectory(candidate) && Files.isDirectory(candidate.resolve(MACHINE_CONFIG_DIRECTORY));
    }
}
