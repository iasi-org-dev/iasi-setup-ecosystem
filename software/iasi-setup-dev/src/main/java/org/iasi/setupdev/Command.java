package org.iasi.setupdev;

import java.util.List;

enum Command {
    HELP(List.of("help"), "general", true, false), PLATFORM(List.of("platform"), "platform", false, true), CREATE(List.of("create"), "create", false,
            false), WORKFLOW_HELP(List.of("workflow", "help"), "workflow", true,
                    false), WORKFLOW_RELEASE(List.of("workflow", "release"), "workflowRelease", false, false);

    private final List<String> words;
    private final String key;
    private final boolean helpEntry;
    private final boolean executable;

    /**
     * Registra sintaxis, clave de ayuda y disponibilidad en una única definición
     * usada por parser y presentación.
     */
    Command(List<String> words, String key, boolean helpEntry, boolean executable) {
        this.words = words;
        this.key = key;
        this.helpEntry = helpEntry;
        this.executable = executable;
    }

    /**
     * Exige coincidencia completa de tokens; rechaza órdenes, ámbitos o targets no
     * declarados.
     */
    static Command resolve(List<String> words) {
        for (Command command : values()) {
            if (command.words.equals(words)) return command;
        }
        throw new InputException("invalidCommand");
    }

    /** Clave del contexto de ayuda en el catálogo propio de iasi-setup-dev. */
    String key() {
        return key;
    }

    /**
     * Sintaxis registrada que se muestra al usuario y se conserva en los eventos de
     * ejecución.
     */
    String syntax() {
        return String.join(" ", words);
    }

    /**
     * Identifica comandos del ámbito workflow para separarlos de acciones directas
     * en la ayuda.
     */
    boolean workflow() {
        return words.getFirst().equals("workflow");
    }

    /** Combina entradas help con -h contextual; no autoriza ejecutar el comando. */
    boolean help(Options options) {
        return helpEntry || options.help();
    }

    /**
     * Distingue diagnóstico implementado de contextos reservados que deben fallar
     * sin simular éxito.
     */
    boolean executable() {
        return executable;
    }
}
