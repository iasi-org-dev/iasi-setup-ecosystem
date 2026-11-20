package org.iasi.setupdev;

import org.iasi.setupdev.console.ContextSummary;
import org.iasi.setupdev.core.Context;
import org.iasi.setupdev.core.Initializer;

/**
 * Defines the process entry point and the current initialize-and-inspect application sequence.
 *
 * @author Javier G. Grandez
 * @since 0.1.0
 * @version 0.1.0
 * @history 2026-11-19 | 0.1.0 | Establish structural documentation and component responsibilities.
 */
public final class App {

    public static void main(String[] args) {
        System.exit(new App().run(args));
    }

    public int run(String[] args) {
        Context ctx = new Initializer().initialize(args);
        if (ctx.isHelp()) return ctx.getRC();
        new ContextSummary().print(ctx, ctx.out());
        return ctx.getRC();
    }
}
