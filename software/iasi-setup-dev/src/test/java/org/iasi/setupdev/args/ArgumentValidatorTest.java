package org.iasi.setupdev.args;

import static org.junit.jupiter.api.Assertions.*;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Map;
import org.junit.jupiter.api.Test;
import org.iasi.setupdev.core.Initializer;
import org.junit.jupiter.api.io.TempDir;

/**
 * Checks mandatory values, typed lists and filesystem preparation for declared arguments.
 *
 * @author Javier G. Grandez
 * @since 0.1.0
 * @version 0.1.0
 * @history 2026-11-19 | 0.1.0 | Establish structural documentation and component responsibilities.
 */
class ArgumentValidatorTest {
    @TempDir
    Path directory;

    @Test
    void checksMissingMandatoryArgumentsAndPreservesTypedLists() throws IOException {
        ArgsList definitions = new ArgsList()
            .add(new ARG("servers", "SERVERS", ArgType.PARM, ArgClass.STRING, true, true, false));
        ArgumentValidator validator = new ArgumentValidator(definitions);
        assertThrows(ArgumentException.class, () -> validator.validateArgs(new WorkingArguments()));
        WorkingArguments working = new WorkingArguments();
        working.setParameter("servers", java.util.List.of("uno", "dos"));
        assertEquals(java.util.List.of("uno", "dos"), validator.validateArgs(working).get("servers"));
    }

    @Test
    void preparesDirectoryAndConvertsEffectiveValues() throws IOException {
        Path logs = directory.resolve("logs");
        var values = new ArgumentValidator(new Initializer().createArgumentDefinitions()).validateArgs(Map.of("logs", logs.toString(), "verbose", "2"));
        assertEquals(logs.toAbsolutePath().normalize(), values.get("logs"));
        assertTrue(Files.isDirectory(logs));
        assertEquals(2, values.get("verbose"));
    }

    @Test
    void rejectsInvalidValuesBeforeCreatingDirectories() {
        Path logs = directory.resolve("logs");
        assertThrows(ArgumentException.class, () -> new ArgumentValidator(new Initializer().createArgumentDefinitions()).validateArgs(
                Map.of("logs", logs.toString(), "verbose", "incorrecto")));
        assertFalse(Files.exists(logs));
    }

    @Test
    void rejectsFileAsDirectory() throws IOException {
        Path file = Files.createFile(directory.resolve("logs"));
        assertThrows(ArgumentException.class, () -> new ArgumentValidator(new Initializer().createArgumentDefinitions()).validateArgs(Map.of("logs", file.toString())));
    }
}
