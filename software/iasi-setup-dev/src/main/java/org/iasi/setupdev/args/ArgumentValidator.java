package org.iasi.setupdev.args;

import java.io.IOException;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * Validates supported working values and constraints before preparing declared filesystem paths.
 *
 * @author Javier G. Grandez
 * @since 0.1.0
 * @version 0.1.0
 * @history 2026-11-19 | 0.1.0 | Establish structural documentation and component responsibilities.
 */
public final class ArgumentValidator {
    private final Map<String, ARG>   definitions;
    private final ArgumentTransformer transformer = new ArgumentTransformer();
    private final ArgumentConstraints constraints = new ArgumentConstraints();

    public ArgumentValidator(ArgsList definitions) {
        this.definitions = definitions.getValues();
    }

    public Map<String, Object> validateArgs(WorkingArguments working) throws IOException {
        checkAcceptedArguments(working);
        Map<String, Object> values = validateArguments(working);
        prepareArguments(values);
        return Map.copyOf(values);
    }

    public Map<String, Object> validateArgs(Map<String, String> values) throws IOException {
        WorkingArguments working = new WorkingArguments();
        for (var entry : values.entrySet())
            working.setParameter(entry.getKey(), List.of(entry.getValue()));
        /**
         * Checks all supplied values before creating declared paths. The caller publishes the returned typed values to its context.
         * @throws IOException if an allowed path cannot be created
         */
        return validateArgs(working);
    }

    private void checkAcceptedArguments(WorkingArguments working) {
        checkNames(working.getParameters());
        checkNames(working.getDefines());
        checkNames(working.getFlags());
    }

    private void checkNames(List<String> names) {
        for (String name : names) {
            if (!definitions.containsKey(name)) throw new ArgumentException("unknownConfigKey");
        }
    }

    private Map<String, Object> validateArguments(WorkingArguments working) {
        Map<String, Object> values = new LinkedHashMap<>();
        for (var entry : definitions.entrySet()) {
            List<String> original = working.getArgument(entry.getKey());
            Object validated = validateArgument(entry.getValue(), original);
            if (validated != null) values.put(entry.getKey(), validated);
        }
        return values;
    }

    private Object validateArgument(ARG definition, List<String> values) {
        if (values == null) {
            if (definition.isMandatory()) throw new ArgumentException("missingValue");
            return null;
        }
        checkMultiplicity(definition, values);
        Object transformed = transformValues(definition, values);
        constraints.check(definition, transformed);
        return transformed;
    }

    private void checkMultiplicity(ARG definition, List<String> values) {
        if (values.isEmpty()) throw new ArgumentException("missingValue");
        if (!definition.isMultiple() && values.size() != 1) throw new ArgumentException("repeatedArgument");
    }

    private Object transformValues(ARG definition, List<String> values) {
        List<Object> transformed = new ArrayList<>();
        for (String value : values)
            transformed.add(transformer.transform(definition, value));
        return definition.isMultiple() ? List.copyOf(transformed) : transformed.getFirst();
    }

    private void prepareArguments(Map<String, Object> values) throws IOException {
        for (var entry : values.entrySet())
            constraints.prepare(definitions.get(entry.getKey()), entry.getValue());
    }
}
