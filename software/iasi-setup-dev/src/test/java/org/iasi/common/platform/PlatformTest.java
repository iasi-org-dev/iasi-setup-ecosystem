package org.iasi.common.platform;

import static org.junit.jupiter.api.Assertions.*;

import java.util.Map;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;

/**
 * Checks host classification and explicit operation status using simulated system properties.
 *
 * @author Javier G. Grandez
 * @since 0.1.0
 * @version 0.1.0
 * @history 2026-11-19 | 0.1.0 | Establish structural documentation and component responsibilities.
 */
class PlatformTest {

    @ParameterizedTest
    @CsvSource({"Windows 11,WINDOWS", "Windows Server 2025,WINDOWS", "Linux,LINUX", "GNU/Linux,LINUX", "Mac OS X,MACOS", "macOS,MACOS", "Darwin,MACOS",
            "FreeBSD,UNKNOWN", "unknown,UNKNOWN"})
    void simulatedOperatingSystems(String name, Platform.Family expected) {
        assertEquals(expected, detect(name).family());
    }

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

    static Platform detect(String name) {
        Map<String, String> properties = Map.of("os.name", name, "os.version", "6.0", "os.arch", "s390x", "java.runtime.version", "25", "java.vendor",
                "test-vendor");
        return Platform.detect(key -> properties.getOrDefault(key, "unknown"));
    }

    @ParameterizedTest
    @CsvSource({"Windows 11,0", "Linux,0", "Darwin,0", "FreeBSD,16", "unknown,16"})
    void platformOperationProducesExplicitRc(String name, int expected) {
        var result = Platform.identify(key -> key.equals("os.name") ? name : "test");
        assertEquals(expected, result.status());
        assertEquals(name, result.value().orElseThrow().name());
    }
}
