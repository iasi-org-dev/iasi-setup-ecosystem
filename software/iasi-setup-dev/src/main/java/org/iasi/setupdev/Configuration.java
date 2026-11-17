package org.iasi.setupdev;

import org.iasisetupdev.core.ExecutionConfiguration;

import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.InvalidPathException;
import java.nio.file.Path;
import java.util.HashMap;
import java.util.Map;
import java.util.Set;
import org.iasi.base.Verbosity;
import org.tomlj.Toml;
import org.tomlj.TomlParseResult;

final class Configuration {
    private static final Set<String> KEYS = Set.of("definitions", "machines", "logs", "verbose");

    /**
     * La resolución es una operación sin estado compartido; no se crean instancias.
     */
    private Configuration() {
    }

    /**
     * Superpone hardcoded, recurso interno, archivo externo y CLI; devuelve rutas
     * validadas sin crear directorios. El stream interno se consume y cierra.
     */
    static ExecutionConfiguration resolve(Options options, Path originalCwd, InputStream internal) throws IOException {
        Path cwd = originalCwd.toAbsolutePath().normalize();
        Map<String, Object> values = new HashMap<>(Map.of("definitions", ".", "machines", ".", "logs", ".", "verbose", false));
        if (internal != null) values.putAll(readLayer(internal));
        String config = options.parameters().get("--config");
        if (config != null) values.putAll(readLayer(Files.newInputStream(path(cwd, config))));
        overlayCli(values, options);
        Verbosity verbosity = Boolean.TRUE.equals(values.get("verbose")) ? Verbosity.VERBOSE : Verbosity.NORMAL;
        if (options.verbosity() != null) verbosity = options.verbosity();
        Path definitions = directory(cwd, values.get("definitions"));
        Path machines = directory(cwd, values.get("machines"));
        Path logs = directory(cwd, values.get("logs"));
        return new ExecutionConfiguration(cwd, definitions, machines, logs, verbosity, options.force());
    }

    /**
     * Sustituye solo directorios indicados explícitamente; force permanece
     * exclusivamente en los flags de la instancia.
     */
    private static void overlayCli(Map<String, Object> values, Options options) {
        for (String name : Set.of("definitions", "machines", "logs")) {
            String explicit = options.parameters().get("--" + name);
            if (explicit != null) values.put(name, explicit);
        }
    }

    /**
     * Valida el TOML completo y sus claves antes de usarlo, y cierra el stream
     * incluso si falla la lectura o validación.
     */
    private static Map<String, Object> readLayer(InputStream input) throws IOException {
        try (input) {
            TomlParseResult parsed = Toml.parse(input);
            if (parsed.hasErrors()) throw new InputException("invalidToml");
            Map<String, Object> values = parsed.toMap();
            for (var entry : values.entrySet())
                validateEntry(entry.getKey(), entry.getValue());
            return values;
        }
    }

    /**
     * Aplica el esquema cerrado de cuatro entradas; rechaza force y los tipos
     * incompatibles.
     */
    private static void validateEntry(String key, Object value) {
        if (!KEYS.contains(key)) throw new InputException("unknownConfigKey");
        boolean valid = switch (key) {
            case "verbose" -> value instanceof Boolean;
            default -> value instanceof String text && !text.isBlank();
        };
        if (!valid) throw new InputException("invalidConfigType");
    }

    /**
     * Resuelve una ruta y rechaza archivos existentes usados como directorios, sin
     * crear el destino.
     */
    private static Path directory(Path cwd, Object value) throws IOException {
        Path resolved = path(cwd, (String) value);
        if (Files.exists(resolved) && !Files.isDirectory(resolved)) throw new IOException("Expected a directory");
        return resolved;
    }

    /**
     * Normaliza siempre contra el CWD original; convierte rutas inválidas en un
     * diagnóstico sin exponer su contenido.
     */
    private static Path path(Path cwd, String value) {
        try {
            return cwd.resolve(Path.of(value)).normalize();
        } catch (InvalidPathException exception) {
            throw new InputException("invalidPath");
        }
    }
}
