package org.iasi.setupdev.args;

import static org.junit.jupiter.api.Assertions.*;

import java.util.List;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import org.junit.jupiter.api.Test;
import org.iasi.setupdev.targets.TargetDiscovery;
import org.junit.jupiter.api.io.TempDir;

class TargetsTest {
    /**
     * Identifica todos los ausentes y conserva la lista original, incluido el válido.
     */
    @Test
    void reportsMissingTargetsWithoutChangingOriginals(@TempDir Path directory) throws IOException {
        Files.createDirectory(directory.resolve("iasi-models"));
        List<String> original = List.of("iasi-model", "iasi-models", "iasi-pepe");
        assertEquals(List.of("iasi-model", "iasi-pepe"), new TargetValidator().validateTargets(new TargetDiscovery().discover(directory), original).missing());
        assertEquals(List.of("iasi-model", "iasi-models", "iasi-pepe"), original);
    }

    /**
     * Expande regex, conserva el orden y evita ejecutar dos veces una coincidencia.
     */
    @Test
    void resolvesPatternsWithoutDuplicates(@TempDir Path directory) throws IOException {
        Path api = Files.createDirectory(directory.resolve("iasi-dev-api"));
        Path ui = Files.createDirectory(directory.resolve("iasi-dev-ui"));
        Files.createDirectory(directory.resolve("otra-maquina"));
        List<String> original = List.of("iasi-dev-.*", "iasi-dev-api", "inexistente.*");
        var result = new TargetValidator().validateTargets(new TargetDiscovery().discover(directory), original);
        assertEquals(List.of(api, ui), result.selected());
        assertEquals(List.of("inexistente.*"), result.missing());
        assertEquals(List.of("iasi-dev-.*", "iasi-dev-api", "inexistente.*"), original);
    }

    /**
     * Sin patrones se seleccionan todos los candidatos del directorio.
     */
    @Test
    void resolvesAllWithoutPatterns(@TempDir Path directory) throws IOException {
        Path target = Files.createDirectory(directory.resolve("iasi-dev-api"));
        Files.createFile(directory.resolve("defaults.toml"));
        var result = new TargetValidator().validateTargets(new TargetDiscovery().discover(directory), List.of());
        assertEquals(List.of(target), result.selected());
        assertTrue(result.missing().isEmpty());
    }

    /**
     * Una expresión mal formada se distingue de una expresión sin coincidencias.
     */
    @Test
    void rejectsMalformedPattern(@TempDir Path directory) throws IOException {
        ArgumentException error = assertThrows(ArgumentException.class,
                () -> new TargetValidator().validateTargets(new TargetDiscovery().discover(directory), List.of("[")));
        assertEquals("invalidTargetPattern", error.getMessage());
    }

    /**
     * Sin posicionales se conserva una lista vacía para la selección posterior.
     */
    @Test
    void noTargetsMeansAllDefinitions() {
        Arguments parsed = new CommandLineLoader();
        assertTrue(parsed.getTargets().isEmpty());
    }

    /**
     * El directorio de búsqueda y los nombres originales son datos independientes.
     */
    @Test
    void separatesDefinitionsDirectoryFromTargets() {
        Arguments parsed = new CommandLineLoader("--definitions", "xxx", "iasi-models", "-v", "otra-maquina");
        assertEquals("xxx", ArgumentAccess.singleValue(parsed, "definitions"));
        assertEquals(List.of("iasi-models", "otra-maquina"), parsed.getTargets());
    }

    /**
     * Cada carga conserva su lista de targets sin compartirla con otra carga.
     */
    @Test
    void preservesImmutableOriginalTargets() {
        Arguments parsed = new CommandLineLoader("iasi-models");
        List<String> original = parsed.getTargets();
        new CommandLineLoader("otra-maquina");
        assertEquals(List.of("iasi-models"), original);
        assertEquals(List.of("iasi-models"), parsed.getTargets());
    }
}
