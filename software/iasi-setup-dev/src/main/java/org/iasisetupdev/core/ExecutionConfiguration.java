package org.iasisetupdev.core;

import java.nio.file.Path;
import java.util.Objects;
import org.iasi.base.Verbosity;

/**
 * Instantánea inmutable de opciones efectivas; no contiene entidades ni
 * colecciones de dominio.
 */
public record ExecutionConfiguration(Path cwd, Path definitions, Path machines, Path logs, Verbosity verbosity, boolean force) {
    /**
     * Conserva valores completos y rutas normalizadas; todos los miembros son
     * valores inmutables.
     */
    public ExecutionConfiguration {
        cwd = Objects.requireNonNull(cwd).toAbsolutePath().normalize();
        definitions = cwd.resolve(Objects.requireNonNull(definitions)).normalize();
        machines = cwd.resolve(Objects.requireNonNull(machines)).normalize();
        logs = cwd.resolve(Objects.requireNonNull(logs)).normalize();
        Objects.requireNonNull(verbosity);
    }
}
