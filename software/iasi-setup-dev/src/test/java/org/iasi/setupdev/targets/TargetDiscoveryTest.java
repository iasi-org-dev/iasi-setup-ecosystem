package org.iasi.setupdev.targets;

import static org.junit.jupiter.api.Assertions.*;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.List;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

/**
 * Checks structural machine discovery independently of configuration contents and target selection.
 *
 * @author Javier G. Grandez
 * @since 0.1.0
 * @version 0.1.0
 * @history 2026-11-20 | 0.1.0 | Cover direct markers, unrelated entries and unchanged invalid-root handling.
 */
class TargetDiscoveryTest {
    @TempDir
    Path root;

    @Test
    void acceptsOnlyImmediateMachineDirectoriesWithDirectMarkers() throws IOException {
        Path models = machine("iasi-models");
        Path tools = machine("iasi-tools");
        Files.createDirectory(root.resolve("backups"));
        Files.createDirectories(root.resolve("iasi-dev/docs"));
        Files.createFile(root.resolve("unrelated.txt"));
        assertEquals(List.of(models, tools), new TargetDiscovery().discover(root));
    }

    @Test
    void excludesMarkersThatAreFilesOrOnlyNestedDescendants() throws IOException {
        Path wrongType = Files.createDirectory(root.resolve("marker-file"));
        Files.createFile(wrongType.resolve(TargetDiscovery.MACHINE_CONFIG_DIRECTORY));
        Files.createDirectories(root.resolve("nested/docs").resolve(TargetDiscovery.MACHINE_CONFIG_DIRECTORY));
        assertTrue(new TargetDiscovery().discover(root).isEmpty());
    }

    @Test
    void doesNotRequireOrParseConfigurationFiles() throws IOException {
        Path empty = machine("empty-config");
        Path malformed = machine("malformed-config");
        Path content = malformed.resolve(TargetDiscovery.MACHINE_CONFIG_DIRECTORY).resolve("machine.toml");
        Files.writeString(content, "invalid = [");
        assertEquals(List.of(empty, malformed), new TargetDiscovery().discover(root));
        assertEquals("invalid = [", Files.readString(content));
        try (var files = Files.list(empty.resolve(TargetDiscovery.MACHINE_CONFIG_DIRECTORY))) {
            assertEquals(0, files.count());
        }
    }

    @Test
    void emptyRootProducesNoCandidatesAndNoFilesystemChanges() throws IOException {
        assertTrue(new TargetDiscovery().discover(root).isEmpty());
        try (var files = Files.list(root)) {
            assertEquals(0, files.count());
        }
    }

    @Test
    void preservesIoErrorsForMissingRootsAndRootsThatAreFiles() throws IOException {
        Path file = Files.createFile(root.resolve("not-a-directory"));
        assertThrows(IOException.class, () -> new TargetDiscovery().discover(file));
        assertThrows(IOException.class, () -> new TargetDiscovery().discover(root.resolve("missing")));
    }

    private Path machine(String name) throws IOException {
        Path machine = root.resolve(name);
        Files.createDirectories(machine.resolve(TargetDiscovery.MACHINE_CONFIG_DIRECTORY));
        return machine;
    }
}
