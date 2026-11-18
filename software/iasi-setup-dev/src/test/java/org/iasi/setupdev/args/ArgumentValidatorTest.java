package org.iasi.setupdev.args;

import static org.junit.jupiter.api.Assertions.*;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Map;
import org.junit.jupiter.api.Test;
import org.iasi.setupdev.core.Initializer;
import org.junit.jupiter.api.io.TempDir;

class ArgumentValidatorTest {
    @TempDir
    Path directory;

    /**
     * El consumidor recibe una ruta preparada y un entero, sin repetir validaciones.
     */
    @Test
    void preparesDirectoryAndConvertsEffectiveValues() throws IOException {
        Path logs = directory.resolve("logs");
        var values = new ArgumentValidator(new Initializer().createArgumentDefinitions()).validateArgs(Map.of("logs", logs.toString(), "verbose", "2"));
        assertEquals(logs.toAbsolutePath().normalize(), values.get("logs"));
        assertTrue(Files.isDirectory(logs));
        assertEquals(2, values.get("verbose"));
    }

    /**
     * Un valor inválido impide crear los directorios solicitados.
     */
    @Test
    void rejectsInvalidValuesBeforeCreatingDirectories() {
        Path logs = directory.resolve("logs");
        assertThrows(ArgumentException.class, () -> new ArgumentValidator(new Initializer().createArgumentDefinitions()).validateArgs(
                Map.of("logs", logs.toString(), "verbose", "incorrecto")));
        assertFalse(Files.exists(logs));
    }

    /**
     * Un archivo existente no se acepta como directorio de logs.
     */
    @Test
    void rejectsFileAsDirectory() throws IOException {
        Path file = Files.createFile(directory.resolve("logs"));
        assertThrows(ArgumentException.class, () -> new ArgumentValidator(new Initializer().createArgumentDefinitions()).validateArgs(Map.of("logs", file.toString())));
    }
}
