package org.iasi.setupdev;

import org.iasi.setupdev.console.ContextSummary;
import org.iasi.setupdev.core.Context;
import org.iasi.setupdev.core.Initializer;

/**
 * Punto de entrada y secuencia de responsabilidades de la aplicación.
 */
public final class App {
    /**
     * Ejecuta una instancia y devuelve al proceso el RC acumulado en su contexto.
     */
    public static void main(String[] args) {
        System.exit(new App().run(args));
    }

    /**
     * Inicializa el contexto, muestra el resumen temporal y devuelve su RC.
     */
    public int run(String[] args) {
        Context ctx = new Initializer().initialize(args);
        new ContextSummary().print(ctx, ctx.out());
        return ctx.getRC();
    }
}
