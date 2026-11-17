package org.iasi.setupdev;

import static org.junit.jupiter.api.Assertions.*;

import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import org.iasi.common.logging.Verbosity;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;

class ConfigurationTest {
    @TempDir
    Path cwd;

    /**
     * Contrasta los defaults reales sin ninguna fuente opcional ni efectos de
     * creación.
     */
    @Test
    void hardcodedDirectoriesAreCwdAndForceIsFalse() throws IOException {
        Settings settings = resolve("");
        assertEquals(cwd, settings.cwd());
        assertEquals(cwd, settings.definitions());
        assertEquals(cwd, settings.machines());
        assertEquals(cwd, settings.logs());
        assertEquals(Verbosity.NORMAL, settings.verbosity());
        assertFalse(settings.force());
    }

    /**
     * Comprueba que las claves ausentes en el recurso interno conservan sus valores
     * anteriores.
     */
    @Test
    void internalLayerOnlyReplacesSuppliedKeys() throws IOException {
        Settings settings = resolve("definitions='built-in'\nverbose=true\n");
        assertEquals(cwd.resolve("built-in"), settings.definitions());
        assertEquals(cwd, settings.machines());
        assertEquals(cwd, settings.logs());
        assertEquals(Verbosity.VERBOSE, settings.verbosity());
        assertFalse(settings.force());
    }

    /** Verifica precedencia por clave y que resolver rutas no crea destinos. */
    @Test
    void externalOverridesInternalAndCliOverridesBoth() throws IOException {
        Files.createDirectories(cwd.resolve("configuration"));
        Files.writeString(cwd.resolve("configuration/instance.toml"), "definitions='external'\nlogs='external-logs'\nverbose=false\n");
        Settings settings = resolve("definitions='internal'\nmachines='internal-vms'\nverbose=true\n", "--config", "configuration/instance.toml", "--logs",
                "cli-logs", "-V", "-s", "-v");
        assertEquals(cwd.resolve("external"), settings.definitions());
        assertEquals(cwd.resolve("internal-vms"), settings.machines());
        assertEquals(cwd.resolve("cli-logs"), settings.logs());
        assertEquals(Verbosity.VERBOSE, settings.verbosity());
        assertFalse(Files.exists(cwd.resolve("cli-logs")));
        assertFalse(Files.exists(cwd.resolve("internal-vms")));
    }

    /**
     * Evita tratar false como una clave ausente al superponer el archivo externo.
     */
    @Test
    void falseInExternalLayerResetsInternalVerbose() throws IOException {
        Files.writeString(cwd.resolve("instance.toml"), "verbose=false\n");
        assertEquals(Verbosity.NORMAL, resolve("verbose=true\n", "--config", "instance.toml").verbosity());
    }

    /**
     * Confirma que la CLI define la verbosidad de la instancia sobre el archivo.
     */
    @Test
    void explicitSilentOverridesConfiguredVerbose() throws IOException {
        Files.writeString(cwd.resolve("instance.toml"), "verbose=true\n");
        Settings settings = resolve("", "--config", "instance.toml", "-V", "-s");
        assertEquals(Verbosity.SILENT, settings.verbosity());
    }

    /**
     * Comprueba que definitions, machines y logs no se sustituyen semánticamente
     * entre sí.
     */
    @Test
    void allDirectoryParametersAreIndependent() throws IOException {
        Settings definitions = resolve("", "--definitions", "defs");
        Settings machines = resolve("", "--machines", "vms");
        Settings both = resolve("", "--definitions", "defs", "--machines", "vms");
        assertEquals(cwd, definitions.machines());
        assertEquals(cwd, machines.definitions());
        assertEquals(cwd.resolve("defs"), both.definitions());
        assertEquals(cwd.resolve("vms"), both.machines());
        assertEquals(cwd, both.logs());
    }

    /**
     * Detecta resoluciones incorrectas contra el directorio del archivo TOML o del
     * ejecutable.
     */
    @Test
    void pathsAreRelativeToOriginalCwdIncludingExternalValues() throws IOException {
        Files.createDirectory(cwd.resolve("config"));
        Files.writeString(cwd.resolve("config/instance.toml"), "logs='a/../audit'\n");
        Settings settings = resolve("", "--config", "config/instance.toml", "--machines", cwd.resolve("absolute").toString());
        assertEquals(cwd.resolve("audit"), settings.logs());
        assertEquals(cwd.resolve("absolute"), settings.machines());
    }

    /** Rechaza claves no declaradas, force, tipos erróneos y TOML defectuoso. */
    @ParameterizedTest
    @ValueSource(strings = {"force=true", "force=false", "unknown='x'", "logs=3", "verbose='true'", "machines=''", "broken ["})
    void invalidOrUndeclaredConfigurationIsRejected(String toml) {
        assertThrows(InputException.class, () -> resolve(toml));
    }

    /**
     * Verifica que -f es el único origen configurable de force para la instancia.
     */
    @Test
    void forceCanOnlyComeFromCli() throws IOException {
        Settings settings = resolve("verbose=true\n", "-f");
        assertTrue(settings.force());
        assertThrows(InputException.class, () -> resolve("force=true\n", "-f"));
    }

    /**
     * Comprueba atomicidad de validación y ausencia de directorios parciales ante
     * un error.
     */
    @Test
    void validatesBeforeApplyingAndRejectsFileAsDirectory() throws IOException {
        Path file = Files.writeString(cwd.resolve("data"), "content");
        assertThrows(IOException.class, () -> resolve("", "--machines", file.toString(), "--logs", "must-not-exist"));
        assertFalse(Files.exists(cwd.resolve("must-not-exist")));
        assertThrows(IOException.class, () -> resolve("", "--logs", file.toString()));
        assertThrows(IOException.class, () -> resolve("", "--definitions", file.toString()));
        assertThrows(IOException.class, () -> resolve("", "--config", "missing.toml"));
    }

    /** Garantiza que archivos próximos no cambian la ejecución sin --config. */
    @Test
    void noConfigurationIsDiscoveredAutomatically() throws IOException {
        Files.writeString(cwd.resolve("defaults.toml"), "verbose=true\n");
        Files.writeString(cwd.resolve("setup.toml"), "logs='unexpected'\n");
        Settings settings = resolve("");
        assertEquals(Verbosity.NORMAL, settings.verbosity());
        assertEquals(cwd, settings.logs());
    }

    /**
     * Construye una fuente interna opcional de prueba y ejecuta la resolución con
     * CWD aislado.
     */
    private Settings resolve(String internal, String... arguments) throws IOException {
        var stream = internal.isEmpty() ? null : new ByteArrayInputStream(internal.getBytes(StandardCharsets.UTF_8));
        return Configuration.resolve(Options.parse(arguments), cwd, stream);
    }
}
