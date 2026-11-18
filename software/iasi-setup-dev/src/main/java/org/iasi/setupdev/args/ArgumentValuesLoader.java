package org.iasi.setupdev.args;

import java.util.ArrayList;

/**
 * Separa comas fuera de comillas. Solo interpreta las comillas que llegan en args;
 * no puede recuperar las que haya retirado el shell.
 */
final class ArgumentValuesLoader {
    public ArrayList<String> loadValues(String text) {
        State state = new State();
        for (int index = 0; index < text.length(); index++)
            state.loadCharacter(text.charAt(index));
        return state.finish();
    }

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
