package org.iasi.setupdev.configuration;

import java.io.IOException;
import org.iasi.setupdev.args.ArgumentException;
import org.iasi.setupdev.args.WorkingArguments;
import org.iasi.setupdev.messages.InitializationMessages;

/**
 * Applies optional bundled TOML defaults before external files, environment values and CLI overrides.
 *
 * @author Javier G. Grandez
 * @since 0.1.0
 * @version 0.1.0
 * @history 2026-11-20 | 0.1.0 | Load the ecosystem defaults resource as an internal configuration layer.
 */
public final class InternalConfiguration {
    private static final String RESOURCE = "/org/iasi/setupdev/defaults.toml";

    public void apply(WorkingArguments working) {
        try (var resource = InternalConfiguration.class.getResourceAsStream(RESOURCE)) {
            if (resource == null) return;
            TomlConfiguration configuration = new TomlConfiguration();
            configuration.apply(configuration.read(resource), working);
        } catch (ArgumentException exception) {
            InitializationMessages.error(exception.getMessage());
        } catch (IOException | SecurityException exception) {
            InitializationMessages.ioError();
        }
    }
}
