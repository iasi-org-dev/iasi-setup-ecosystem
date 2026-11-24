package org.iasi.common.platform;

import java.util.Locale;
import java.util.function.Function;
import org.iasi.base.RC;

import org.iasi.common.operation.OperationResult;

/**
 * Describes host OS and runtime properties without claiming virtualization capabilities.
 *
 * @author Javier G. Grandez
 * @since 0.1.0
 * @version 0.1.0
 * @history 2026-11-19 | 0.1.0 | Establish structural documentation and component responsibilities.
 */
public record Platform(Family family, String name, String version, String architecture, String runtime, String vendor) {

    /**
     * Groups recognized operating systems while retaining an explicit unknown case.
     *
     * @author Javier G. Grandez
     * @since 0.1.0
     * @version 0.1.0
     * @history 2026-11-19 | 0.1.0 | Establish structural documentation and component responsibilities.
     */
    public enum Family {
        WINDOWS, LINUX, MACOS, UNKNOWN
    }

    public static Family getOperatingSystem() {
        return detect().family();
    }

    public static Platform detect() {
        return detect(key -> System.getProperty(key, "unknown"));
    }

    public static OperationResult<Platform> identify() {
        return identify(key -> System.getProperty(key, "unknown"));
    }

    public static OperationResult<Platform> identify(Function<String, String> properties) {
        Platform platform = detect(properties);
        int status = RC.OK;
        if (platform.family() == Family.UNKNOWN) status |= RC.ERROR;
        return OperationResult.withValue(platform, status);
    }

    public static Platform detect(Function<String, String> properties) {
        String name = properties.apply("os.name");
        return new Platform(family(name), name, properties.apply("os.version"), properties.apply("os.arch"), properties.apply("java.runtime.version"),
                properties.apply("java.vendor"));
    }

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
