package org.iasi.setupdev.args;

import java.util.ArrayList;

/**
 * Splits comma-separated values while respecting quotes that survived shell tokenization.
 *
 * @author Javier G. Grandez
 * @since 0.1.0
 * @version 0.1.0
 * @history 2026-11-19 | 0.1.0 | Establish structural documentation and component responsibilities.
 */
final class ArgumentValuesLoader {
    public ArrayList<String> loadValues(String text) {
        State state = new State();
        for (int index = 0; index < text.length(); index++)
            state.loadCharacter(text.charAt(index));
        return state.finish();
    }

    /**
     * Tracks the current quoted segment and completed values during one parameter scan.
     *
     * @author Javier G. Grandez
     * @since 0.1.0
     * @version 0.1.0
     * @history 2026-11-19 | 0.1.0 | Establish structural documentation and component responsibilities.
     */
    private static final class State {
        private final ArrayList<String> values = new ArrayList<>();
        private final StringBuilder     value  = new StringBuilder();
        private char                    quote;

        private void loadCharacter(char character) {
            if (quote != 0) loadQuotedCharacter(character);
            else if (character == '\'' || character == '"') quote = character;
            else if (character == ',') finishValue();
            else value.append(character);
        }

        private void loadQuotedCharacter(char character) {
            if (character == quote) quote = 0;
            else value.append(character);
        }

        private void finishValue() {
            if (value.isEmpty() || value.toString().isBlank()) throw new ArgumentException("missingValue");
            values.add(value.toString());
            value.setLength(0);
        }

        private ArrayList<String> finish() {
            if (quote != 0) throw new ArgumentException("invalidQuotes");
            finishValue();
            return values;
        }
    }
}
