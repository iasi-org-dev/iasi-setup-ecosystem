package org.iasi.setupdev.configuration;

import static org.junit.jupiter.api.Assertions.*;

import java.io.ByteArrayInputStream;
import java.nio.charset.StandardCharsets;
import java.nio.file.Path;
import org.iasi.setupdev.args.layer.CommandLineArguments;
import org.iasi.setupdev.args.loader.CommandLineLoader;
import org.iasi.setupdev.args.model.WorkingArguments;
import org.iasi.setupdev.core.Initializer;
import org.junit.jupiter.api.Test;

/**
 * Checks bundled defaults and later-layer overrides without preparing application directories.
 *
 * @author Javier G. Grandez
 * @since 0.1.0
 * @version 0.1.0
 * @history 2026-11-20 | 0.1.0 | Cover the shared source resource and its configuration precedence.
 */
class InternalConfigurationTest {
    @Test
    void loadsTheEcosystemDefaultsResourceAsText() throws Exception {
        WorkingArguments actual = new WorkingArguments();
        new InternalConfiguration().apply(actual);
        TomlConfiguration configuration = new TomlConfiguration();
        WorkingArguments expected = new WorkingArguments();
        configuration.apply(configuration.read(Path.of("../../definitions/defaults.toml")), expected);
        assertFalse(actual.getParameters().isEmpty());
        assertEquals(expected.singleValues(), actual.singleValues());
    }

    @Test
    void externalConfigurationAndCliOverrideTheBundledLayer() throws Exception {
        WorkingArguments working = new WorkingArguments();
        new InternalConfiguration().apply(working);
        TomlConfiguration configuration = new TomlConfiguration();
        var external = new ByteArrayInputStream("logs='external'\nverbose=2\n".getBytes(StandardCharsets.UTF_8));
        configuration.apply(configuration.read(external), working);
        assertEquals("external", working.singleValues().get("logs"));
        assertEquals("2", working.singleValues().get("verbose"));
        var definitions = new Initializer().createArgumentDefinitions();
        new CommandLineArguments(definitions, working).apply(new CommandLineLoader("--logs", "cli", "-V"));
        assertEquals("cli", working.singleValues().get("logs"));
        assertEquals("3", working.singleValues().get("verbose"));
    }
}
