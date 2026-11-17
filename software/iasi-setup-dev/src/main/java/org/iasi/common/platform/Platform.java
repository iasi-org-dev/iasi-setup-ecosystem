package org.iasi.common.platform;

import java.util.Locale;
import java.util.function.Function;
import org.iasi.base.RC;

import org.iasi.common.operation.OperationResult;

public record Platform(Family family, String name, String version, String architecture, String runtime, String vendor) {
    public enum Family {
        WINDOWS, LINUX, MACOS, UNKNOWN
    }

    /**
     * Captura propiedades del runtime actual sin consultar hipervisores ni
     * modificar el host.
     */
    public static Platform detect() {
        return detect(key -> System.getProperty(key, "unknown"));
    }

    /**
     * Propaga el resultado del diagnóstico como RC IASI, sin asociarlo al número de
     * mensajes emitidos.
     */
    public static OperationResult<Platform> identify() {
        return identify(key -> System.getProperty(key, "unknown"));
    }

    /**
     * Permite verificar el RC de cada familia sin cambiar propiedades globales ni
     * depender del SO físico.
     */
    public static OperationResult<Platform> identify(Function<String, String> properties) {
        Platform platform = detect(properties);
        int status = RC.OK;
        if (platform.family() == Family.UNKNOWN) status |= RC.ERROR;
        return OperationResult.withValue(platform, status);
    }

    /**
     * Construye la descripción desde propiedades inyectadas para probar otras
     * plataformas sin disponer de ellas.
     */
    public static Platform detect(Function<String, String> properties) {
        String name = properties.apply("os.name");
        return new Platform(family(name), name, properties.apply("os.version"), properties.apply("os.arch"), properties.apply("java.runtime.version"),
                properties.apply("java.vendor"));
    }

    /**
     * Clasifica el nombre del SO de forma conservadora; una familia reconocida no
     * implica capacidades de virtualización.
     */
    private static Family family(String name) {
        String normalized = name.toLowerCase(Locale.ROOT);
        if (normalized.startsWith("windows")) return Family.WINDOWS;
        return switch (normalized) {
            case "linux", "gnu/linux" -> Family.LINUX;
            case "mac os x", "macos", "darwin" -> Family.MACOS;
            default -> Family.UNKNOWN;
        };
    }
}
