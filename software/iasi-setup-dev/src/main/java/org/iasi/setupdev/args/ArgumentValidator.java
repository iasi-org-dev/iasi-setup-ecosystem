package org.iasi.setupdev.args;

import java.io.IOException;
import java.net.URI;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.LocalDate;
import java.util.HashMap;
import java.util.Map;

/**
 * Convierte y valida los valores efectivos antes de incorporarlos al contexto.
 */
public final class ArgumentValidator {
    private final Map<String, ARG> definitions;

    public ArgumentValidator(ArgsList definitions) {
        this.definitions = definitions.getValues();
    }

    /**
     * Valida todos los valores y después prepara las rutas según su declaración.
     * Devuelve los valores convertidos sin modificar el contexto.
     */
    public Map<String, Object> validateArgs(Map<String, String> values) throws IOException {
        checkNames(values);
        Map<String, Object> result = convertValues(values);
        checkPaths(result);
        preparePaths(result);
        return Map.copyOf(result);
    }

    /**
     * Rechaza valores que no estén declarados en el esquema de argumentos.
     */
    private void checkNames(Map<String, String> values) {
        for (String name : values.keySet()) {
            if (!definitions.containsKey(name)) throw new ArgumentException("unknownConfigKey");
        }
    }

    /**
     * Comprueba la obligatoriedad y convierte los valores presentes.
     */
    private Map<String, Object> convertValues(Map<String, String> values) {
        Map<String, Object> result = new HashMap<>();
        for (var entry : definitions.entrySet()) {
            String value = values.get(entry.getKey());
            ARG definition = entry.getValue();
            if (value == null) {
                if (definition.isMandatory()) throw new ArgumentException("missingValue");
                continue;
            }
            result.put(entry.getKey(), convert(definition, value));
        }
        return result;
    }

    /**
     * Comprueba las rutas antes de comenzar a crearlas.
     */
    private void checkPaths(Map<String, Object> result) {
        for (var entry : result.entrySet())
            checkPath(definitions.get(entry.getKey()), entry.getValue());
    }

    /**
     * Prepara las rutas cuya declaración permite crearlas.
     */
    private void preparePaths(Map<String, Object> result) throws IOException {
        for (var entry : result.entrySet())
            preparePath(definitions.get(entry.getKey()), entry.getValue());
    }

    /**
     * Convierte el texto al tipo declarado y verifica los límites numéricos.
     */
    private Object convert(ARG definition, String value) {
        if (value.isBlank()) throw new ArgumentException("missingValue");
        try {
            return switch (definition.getArgClass()) {
                case STRING -> value;
                case BOOLEAN -> booleanValue(value);
                case INTEGER -> integerValue(definition, value);
                case NATURAL -> naturalValue(definition, value);
                case FLOAT -> floatValue(definition, value);
                case FILE, DIRECTORY -> Path.of(value).toAbsolutePath().normalize();
                case URL -> urlValue(value);
                case DATE -> LocalDate.parse(value);
                case TIME -> java.time.LocalTime.parse(value);
                case TMS -> java.time.LocalDateTime.parse(value);
                case MAIL -> mailValue(value);
            };
        } catch (ArgumentException exception) {
            throw exception;
        } catch (IllegalArgumentException | java.time.DateTimeException exception) {
            throw new ArgumentException("invalidConfigType");
        }
    }

    /**
     * Exige un literal booleano antes de convertirlo.
     */
    private boolean booleanValue(String value) {
        if (!value.equalsIgnoreCase("true") && !value.equalsIgnoreCase("false")) throw new ArgumentException("invalidConfigType");
        return Boolean.parseBoolean(value);
    }

    /**
     * Convierte un entero y comprueba los límites declarados.
     */
    private int integerValue(ARG definition, String value) {
        int number = Integer.parseInt(value);
        checkRange(definition, number);
        return number;
    }

    private int naturalValue(ARG definition, String value) {
        int number = integerValue(definition, value);
        if (number <= 0) throw new ArgumentException("invalidRange");
        return number;
    }

    private java.math.BigDecimal floatValue(ARG definition, String value) {
        java.math.BigDecimal number = new java.math.BigDecimal(value);
        checkRange(definition, number);
        return number;
    }

    private void checkRange(ARG definition, long number) {
        if (definition.getMinimum() != null && number < definition.getMinimum()) throw new ArgumentException("invalidRange");
        if (definition.getMaximum() != null && number > definition.getMaximum()) throw new ArgumentException("invalidRange");
    }

    private void checkRange(ARG definition, java.math.BigDecimal number) {
        if (definition.getMinimum() != null && number.compareTo(java.math.BigDecimal.valueOf(definition.getMinimum())) < 0)
            throw new ArgumentException("invalidRange");
        if (definition.getMaximum() != null && number.compareTo(java.math.BigDecimal.valueOf(definition.getMaximum())) > 0)
            throw new ArgumentException("invalidRange");
    }

    private String mailValue(String value) {
        if (!value.matches("[^\\s@]+@[^\\s@]+\\.[^\\s@]+")) throw new ArgumentException("invalidConfigType");
        return value;
    }

    /**
     * Admite URI absolutas, incluidas URL y URN.
     */
    private URI urlValue(String value) {
        URI uri = URI.create(value);
        if (!uri.isAbsolute()) throw new ArgumentException("invalidConfigType");
        return uri;
    }

    /**
     * Comprueba las rutas existentes y las que se declararon obligatorias.
     */
    private void checkPath(ARG definition, Object value) {
        if (!(value instanceof Path path)) return;
        if (!Files.exists(path)) {
            if (definition.isRequired()) throw new ArgumentException("invalidPath");
            return;
        }
        boolean valid = definition.getArgClass() == ArgClass.DIRECTORY ? Files.isDirectory(path) : Files.isRegularFile(path);
        if (!valid) throw new ArgumentException("invalidPath");
    }

    /**
     * Crea las rutas ausentes cuya declaración permite su creación.
     */
    private void preparePath(ARG definition, Object value) throws IOException {
        if (!(value instanceof Path path) || definition.isRequired() || Files.exists(path)) return;
        if (definition.getArgClass() == ArgClass.DIRECTORY) Files.createDirectories(path);
        else Files.createFile(path);
    }
}
