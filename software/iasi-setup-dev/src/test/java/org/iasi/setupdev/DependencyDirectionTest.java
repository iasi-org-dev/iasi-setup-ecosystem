package org.iasi.setupdev;

import static org.junit.jupiter.api.Assertions.*;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.regex.Pattern;
import org.junit.jupiter.api.Test;

class DependencyDirectionTest {
    /**
     * El paquete base solo depende del JDK; common no puede importar el launcher
     * que lo consume.
     */
    @Test
    void layersOnlyDependOnLowerLayers() throws IOException {
        try (var sources = Files.walk(Path.of("src/main/java/org/iasi"))) {
            for (Path source : sources.filter(path -> path.toString().endsWith(".java")).toList())
                checkImports(source);
        }
    }

    /**
     * La salida normal pertenece a App y los abortos de inicialización a sus
     * mensajes; los paquetes comunes no terminan la JVM.
     */
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

    /**
     * App reúne el punto de entrada estático y run de instancia, sin una clase Main
     * separada.
     */
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

    /**
     * Comprueba las fronteras en imports reales y no en ejemplos o comentarios de
     * documentación.
     */
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
