package org.iasi.setupdev.args;

import org.iasi.setupdev.targets.TargetValidator;

import org.iasi.setupdev.args.access.ArgumentAccess;
import org.iasi.setupdev.args.model.*;
import org.iasi.setupdev.args.loader.*;
import org.iasi.setupdev.args.layer.*;
import org.iasi.setupdev.args.validation.*;
import static org.junit.jupiter.api.Assertions.*;

import java.util.List;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import org.junit.jupiter.api.Test;
import org.iasi.setupdev.targets.TargetDiscovery;
import org.junit.jupiter.api.io.TempDir;

/**
 * Checks regex selection, unmatched patterns and preservation of original target lists.
 *
 * @author Javier G. Grandez
 * @since 0.1.0
 * @version 0.1.0
 * @history 2026-11-19 | 0.1.0 | Establish structural documentation and component responsibilities.
 */
class TargetsTest {

    @Test
    void reportsMissingTargetsWithoutChangingOriginals(@TempDir Path directory) throws IOException {
        Files.createDirectories(directory.resolve("iasi-models").resolve(TargetDiscovery.MACHINE_CONFIG_DIRECTORY));
        List<String> original = List.of("iasi-model", "iasi-models", "iasi-pepe");
        assertEquals(List.of("iasi-model", "iasi-pepe"), new TargetValidator().validateTargets(new TargetDiscovery().discover(directory), original).missing());
        assertEquals(List.of("iasi-model", "iasi-models", "iasi-pepe"), original);
    }

    @Test
    void resolvesPatternsWithoutDuplicates(@TempDir Path directory) throws IOException {
        Path api = Files.createDirectory(directory.resolve("iasi-dev-api"));
        Path ui = Files.createDirectory(directory.resolve("iasi-dev-ui"));
        Files.createDirectory(api.resolve(TargetDiscovery.MACHINE_CONFIG_DIRECTORY));
        Files.createDirectory(ui.resolve(TargetDiscovery.MACHINE_CONFIG_DIRECTORY));
        Files.createDirectory(directory.resolve("otra-maquina"));
        List<String> original = List.of("iasi-dev-.*", "iasi-dev-api", "inexistente.*");
        var result = new TargetValidator().validateTargets(new TargetDiscovery().discover(directory), original);
        assertEquals(List.of(api, ui), result.selected());
        assertEquals(List.of("inexistente.*"), result.missing());
        assertEquals(List.of("iasi-dev-.*", "iasi-dev-api", "inexistente.*"), original);
    }

    @Test
    void resolvesAllWithoutPatterns(@TempDir Path directory) throws IOException {
        Path target = Files.createDirectory(directory.resolve("iasi-dev-api"));
        Files.createDirectory(target.resolve(TargetDiscovery.MACHINE_CONFIG_DIRECTORY));
        Files.createFile(directory.resolve("defaults.toml"));
        var result = new TargetValidator().validateTargets(new TargetDiscovery().discover(directory), List.of());
        assertEquals(List.of(target), result.selected());
        assertTrue(result.missing().isEmpty());
    }

    @Test
    void rejectsMalformedPattern(@TempDir Path directory) throws IOException {
        ArgumentException error = assertThrows(ArgumentException.class,
                () -> new TargetValidator().validateTargets(new TargetDiscovery().discover(directory), List.of("[")));
        assertEquals("invalidTargetPattern", error.getMessage());
    }

    @Test
    void noTargetsMeansAllDefinitions() {
        Arguments parsed = new CommandLineLoader();
        assertTrue(parsed.getTargets().isEmpty());
    }

    @Test
    void separatesDefinitionsDirectoryFromTargets() {
        Arguments parsed = new CommandLineLoader("--definitions", "xxx", "iasi-models", "-v", "otra-maquina");
        assertEquals("xxx", ArgumentAccess.singleValue(parsed, "definitions"));
        assertEquals(List.of("iasi-models", "otra-maquina"), parsed.getTargets());
    }

    @Test
    void preservesImmutableOriginalTargets() {
        Arguments parsed = new CommandLineLoader("iasi-models");
        List<String> original = parsed.getTargets();
        new CommandLineLoader("otra-maquina");
        assertEquals(List.of("iasi-models"), original);
        assertEquals(List.of("iasi-models"), parsed.getTargets());
    }
}
