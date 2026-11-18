package org.iasi.setupdev.targets;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Comparator;
import java.util.List;

/**
 * Descubrimiento de las carpetas de targets en el directorio de definiciones.
 */
public final class TargetDiscovery {
    /**
     * Obtiene las carpetas inmediatas de targets en orden estable, sin incluir
     * archivos de configuración ni aplicar patrones de selección.
     */
    public List<Path> discover(Path definitions) throws IOException {
        try (var entries = Files.list(definitions)) {
            return entries.filter(Files::isDirectory)
                    .sorted(Comparator.comparing(path -> path.getFileName().toString()))
                    .toList();
        }
    }
}
