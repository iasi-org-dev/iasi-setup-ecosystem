package org.iasi.setupdev;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import org.iasi.common.logging.Verbosity;

record Options(boolean help, boolean force, Verbosity verbosity, Map<String, String> parameters, List<String> words) {
    private static final Set<String> PARAMETERS = Set.of("--config", "--definitions", "--machines", "--logs");

    /**
     * Copia las colecciones para que las opciones analizadas no cambien durante la
     * resolución de configuración.
     */
    Options {
        parameters = Map.copyOf(parameters);
        words = List.copyOf(words);
    }

    /**
     * Recorre tokens sin efectos externos y conserva el último flag de verbosidad
     * indicado, también en grupos.
     */
    static Options parse(String... arguments) {
        State state = new State();
        for (int index = 0; index < arguments.length; index++) {
            String token = arguments[index];
            if (token.startsWith("--")) index = state.parameter(arguments, index);
            else if (token.startsWith("-")) state.flags(token);
            else state.words.add(token);
        }
        return new Options(state.help, state.force, state.verbosity, state.parameters, state.words);
    }

    private static final class State {
        private boolean help;
        private boolean force = false;
        private Verbosity verbosity;
        private final Map<String, String> parameters = new HashMap<>();
        private final List<String> words = new ArrayList<>();

        /**
         * Consume un valor separado como token literal; una repetición sustituye el
         * valor anterior de ese parámetro.
         */
        private int parameter(String[] arguments, int index) {
            String name = arguments[index];
            if (!PARAMETERS.contains(name)) throw new InputException("unknownParameter");
            int valueIndex = index + 1;
            if (valueIndex >= arguments.length || arguments[valueIndex].isBlank()) throw new InputException("missingValue");
            parameters.put(name, arguments[valueIndex]);
            return valueIndex;
        }

        /**
         * Procesa un grupo de flags en su orden original y rechaza el guion aislado.
         */
        private void flags(String token) {
            if (token.length() == 1) throw new InputException("unknownFlag");
            for (char flag : token.substring(1).toCharArray())
                applyFlag(flag);
        }

        /**
         * Aplica un único modificador; solo -f cambia force y la última selección de
         * verbosidad prevalece.
         */
        private void applyFlag(char flag) {
            switch (flag) {
                case 'h' -> help = true;
                case 'f' -> force = true;
                case 'v' -> verbosity = Verbosity.VERBOSE;
                case 'V' -> verbosity = Verbosity.VERY_VERBOSE;
                case 's' -> verbosity = Verbosity.SILENT;
                default -> throw new InputException("unknownFlag");
            }
        }
    }
}
