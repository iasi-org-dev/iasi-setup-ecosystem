package org.iasi.setupdev.console;

import java.io.PrintStream;
import java.nio.file.Path;
import org.iasi.setupdev.core.Context;

/**
 * Resumen temporal de diagnóstico, destinado exclusivamente a consola.
 */
public final class ContextSummary {
    /**
     * Muestra los valores efectivos del contexto después de su validación.
     */
    public void print(Context ctx, PrintStream out) {
        out.printf("""
                Context:
                  cwd      = %s
                  definitions = %s
                  machines = %s
                  logs     = %s
                  env      = %s
                  verbose  = %d
                  force    = %s
                  autostart = %s
                  help     = %s
                  RC       = %d
                  targets  = %s
                  resolvedTargets = %s
                """, Path.of("").toAbsolutePath().normalize(),
                ctx.getDefinitions(), ctx.getMachines(), ctx.getLogs(), ctx.getEnv(),
                ctx.getVerbose(), ctx.isForce(), ctx.isAutostart(), ctx.isHelp(), ctx.getRC(), ctx.getTargets(), ctx.getResolvedTargets());
    }
}
