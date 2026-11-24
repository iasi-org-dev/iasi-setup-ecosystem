package org.iasi.args.loader;

import org.iasi.args.model.*;
import org.iasi.args.layer.*;
import org.iasi.args.validation.*;
import org.iasi.setupdev.messages.InitializationMessages;

/**
 * Loads CLI syntax during construction and aborts locally on malformed tokens, without consulting the argument schema.
 *
 * @author Javier G. Grandez
 * @since 0.1.0
 * @version 0.1.0
 * @history 2026-11-19 | 0.1.0 | Establish structural documentation and component responsibilities.
 */
public final class CommandLineLoader extends Arguments {
    public CommandLineLoader(String... tokens) {
        try {
            loadTokens(this, tokens);
        } catch (ArgumentException exception) {
            InitializationMessages.inputError(exception.getMessage());
        }
    }

    public static void loadTokens(Arguments arguments, String... tokens) {
        for (int index = 0; index < tokens.length; index++) {
            String token = tokens[index];
            if (token.startsWith("--")) index = loadParameter(arguments, tokens, index);
            else if (token.startsWith("-")) loadFlags(arguments, token);
            else arguments.getTargets().add(token);
        }
    }

    private static void loadFlags(Arguments arguments, String token) {
        if (token.length() == 1) throw new ArgumentException("unknownFlag");
        for (int index = 1; index < token.length(); index++)
            arguments.getFlags().add(String.valueOf(token.charAt(index)));
    }

    private static int loadParameter(Arguments arguments, String[] tokens, int index) {
        String name = tokens[index].substring(2);
        if (name.isBlank()) throw new ArgumentException("unknownParameter");
        int valueIndex = index + 1;
        if (valueIndex >= tokens.length) throw new ArgumentException("missingValue");
        String value = tokens[valueIndex];
        if (value.isBlank() || value.startsWith("-")) throw new ArgumentException("missingValue");
        var values = new ArgumentValuesLoader().loadValues(value);
        arguments.getParameters().add(name);
        arguments.getParameterValues().add(values);
        return valueIndex;
    }
}
