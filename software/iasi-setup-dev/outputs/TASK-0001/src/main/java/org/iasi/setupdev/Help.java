package org.iasi.setupdev;

import java.io.PrintStream;
import org.iasi.common.i18n.MessageCatalog;

final class Help {
    /**
     * Presentación sin estado; sus operaciones no inicializan configuración ni
     * logging.
     */
    private Help() {
    }

    /**
     * Presenta el contexto solicitado y sus categorías sin iniciar una operación ni
     * crear archivos.
     */
    static void show(Command command, MessageCatalog catalog, PrintStream out) {
        out.println(catalog.text("help." + command.key()));
        if (command == Command.HELP) showCommands(catalog, out);
        out.println(catalog.text("help.flags"));
        out.println(catalog.text("help.parameters"));
        out.println(catalog.text("help.targets"));
    }

    /**
     * Agrupa las mismas definiciones reconocidas por el parser, separando acciones
     * de workflows.
     */
    private static void showCommands(MessageCatalog catalog, PrintStream out) {
        for (boolean workflow : new boolean[]{false, true}) {
            out.println(catalog.text(workflow ? "help.workflows" : "help.actions"));
            for (Command entry : Command.values()) {
                if (entry.workflow() == workflow) out.println("  " + entry.syntax() + " — " + catalog.text("description." + entry.key()));
            }
        }
    }
}
