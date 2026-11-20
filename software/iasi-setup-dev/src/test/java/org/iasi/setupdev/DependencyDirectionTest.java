package org.iasi.setupdev;

import static org.junit.jupiter.api.Assertions.*;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.regex.Pattern;
import org.junit.jupiter.api.Test;

/**
 * Protects reusable package boundaries and application-owned process termination points.
 *
 * @author Javier G. Grandez
 * @since 0.1.0
 * @version 0.1.0
 * @history 2026-11-19 | 0.1.0 | Establish structural documentation and component responsibilities.
 */
class DependencyDirectionTest {

    @Test
    void layersOnlyDependOnLowerLayers() throws IOException {
        try (var sources = Files.walk(Path.of("src/main/java/org/iasi"))) {
            for (Path source : sources.filter(path -> path.toString().endsWith(".java")).toList())
                checkImports(source);
        }
    }

    @Test
    void terminationStaysAtApplicationBoundaries() throws IOException {
        try (var sources = Files.walk(Path.of("src/main/java"))) {
            for (Path source : sources.filter(path -> path.toString().endsWith(".java")).toList()) {
                String code = Files.readString(source);
                long calls = Pattern.compile("System\\.exit\\s*\\(").matcher(code).results().count();
                String name = source.getFileName().toString();
                assertEquals(name.equals("App.java") || name.equals("InitializationMessages.java") ? 1 : 0, calls, source.toString());
                assertFalse(code.contains("Runtime.getRuntime().halt("));
                assertFalse(code.contains("Runtime.getRuntime().exit("));
            }
        }
    }

    @Test
    void appContainsStaticEntryPointAndInstanceRun() throws Exception {
        var main = App.class.getMethod("main", String[].class);
        var run = App.class.getMethod("run", String[].class);
        assertTrue(java.lang.reflect.Modifier.isStatic(main.getModifiers()));
        assertFalse(java.lang.reflect.Modifier.isStatic(run.getModifiers()));
        assertEquals(int.class, run.getReturnType());
        assertNotNull(App.class.getConstructor());
        assertFalse(Files.exists(Path.of("src/main/java/org/iasi/setupdev/Main.java")));
    }

    private void checkImports(Path source) throws IOException {
        String file = source.toString().replace('\\', '/');
        for (String line : Files.readAllLines(source)) {
            if (line.startsWith("import org.iasi")) {
                if (file.contains("/base/")) assertTrue(line.startsWith("import org.iasi.base."), "Base depends on an upper layer: " + source);
                if (file.contains("/common/")) assertFalse(line.contains("org.iasi.setupdev") || line.contains("org.iasisetupdev"), source.toString());
            }
        }
    }
}
