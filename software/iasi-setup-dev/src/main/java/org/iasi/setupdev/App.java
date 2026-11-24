package org.iasi.setupdev;

import org.iasi.setupdev.console.ContextSummary;
import org.iasi.setupdev.core.Context;
import org.iasi.setupdev.core.Initializer;
import org.iasi.setupdev.core.StartupChecks;

/**
 * Defines the process entry point and the current initialize-and-inspect application sequence.
 *
 * @author Javier G. Grandez
 * @since 0.1.0
 * @version 0.1.0
 * @history 2026-11-19 | 0.1.0 | Establish structural documentation and component responsibilities.
 * @history 2026-11-20 | 0.1.0 | Check the operating system and administrator privileges at the process entry point.
 * @history 2026-11-20 | 0.1.0 | Hold a process-wide NIO instance lock until controlled or JVM shutdown cleanup.
 */
public final class App {
    public static void main(String[] args) {
        Context ctx = Context.getInstance();
        StartupChecks.identifyOperatingSystem(ctx);
        StartupChecks.checkAdministrator(ctx.getOS());
        StartupChecks.acquireInstanceLock("iasi");
        try {
            new App().run(args);
        } finally {
            StartupChecks.releaseInstanceLock("iasi");
        }
        System.exit(ctx.getRC());
    }

    public int run(String[] args) {
        Context ctx = new Initializer().initialize(args);
        if (ctx.isHelp()) return ctx.getRC();
        new ContextSummary().print(ctx, ctx.out());
        return ctx.getRC();
    }
}
