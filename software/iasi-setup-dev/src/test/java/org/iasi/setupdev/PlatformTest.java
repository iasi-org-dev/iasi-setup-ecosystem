package org.iasi.setupdev;

import static org.junit.jupiter.api.Assertions.*;

import java.util.Map;
import org.iasi.common.platform.Platform;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;

class PlatformTest {
    /**
     * Ejercita familias de SO mediante propiedades inyectadas sin hosts físicos
     * adicionales.
     */
    @ParameterizedTest
    @CsvSource({"Windows 11,WINDOWS", "Windows Server 2025,WINDOWS", "Linux,LINUX", "GNU/Linux,LINUX", "Mac OS X,MACOS", "macOS,MACOS", "Darwin,MACOS",
            "FreeBSD,UNKNOWN", "unknown,UNKNOWN"})
    void simulatedOperatingSystems(String name, Platform.Family expected) {
        assertEquals(expected, detect(name).family());
    }

    /**
     * Comprueba que runtime y arquitectura no se confunden con capacidades de
     * hipervisor.
     */
    @Test
    void preservesStructuredFieldsWithoutProviderAssumptions() {
        Platform platform = detect("Linux");
        assertEquals("Linux", platform.name());
        assertEquals("6.0", platform.version());
        assertEquals("s390x", platform.architecture());
        assertEquals("25", platform.runtime());
        assertEquals("test-vendor", platform.vendor());
        assertNotNull(Platform.detect().family());
    }

    /**
     * Construye propiedades de prueba deterministas, incluida una arquitectura
     * distinta del host.
     */
    static Platform detect(String name) {
        Map<String, String> properties = Map.of("os.name", name, "os.version", "6.0", "os.arch", "s390x", "java.runtime.version", "25", "java.vendor",
                "test-vendor");
        return Platform.detect(key -> properties.getOrDefault(key, "unknown"));
    }
}
