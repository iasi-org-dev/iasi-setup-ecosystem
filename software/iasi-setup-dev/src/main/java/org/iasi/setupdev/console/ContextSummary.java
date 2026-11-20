package org.iasi.setupdev.console;

import java.io.PrintStream;
import java.nio.file.Path;
import org.iasi.setupdev.core.Context;

/**
 * Prints the temporary console-only view of effective execution values and target selections.
 *
 * @author Javier G. Grandez
 * @since 0.1.0
 * @version 0.1.0
 * @history 2026-11-19 | 0.1.0 | Establish structural documentation and component responsibilities.
 */
public final class ContextSummary {

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
