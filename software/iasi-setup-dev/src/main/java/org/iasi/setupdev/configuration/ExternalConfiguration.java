package org.iasi.setupdev.configuration;

import java.io.IOException;
import java.nio.file.Path;
import org.iasi.setupdev.args.ArgumentException;
import org.iasi.setupdev.args.Arguments;
import org.iasi.setupdev.args.ArgumentAccess;
import org.iasi.setupdev.args.WorkingArguments;
import org.iasi.setupdev.messages.InitializationMessages;
import java.nio.file.Files;
import java.nio.file.InvalidPathException;

/**
 * Loads one external TOML layer into textual working arguments without provisioning machines.
 *
 * @author Javier G. Grandez
 * @since 0.1.0
 * @version 0.1.0
 * @history 2026-11-19 | 0.1.0 | Establish structural documentation and component responsibilities.
 * @history 2026-11-19 | 0.1.0 | Distinguish missing configuration paths from paths with the wrong filesystem type.
 * @history 2026-11-20 | 0.1.0 | Reuse the TOML reader shared with bundled configuration.
 */
public final class ExternalConfiguration {
    public void apply(Arguments commandLine, WorkingArguments working) {
        try {
            switch (commandLine.count("config")) {
                case 0: return;
                case 1: applyFile(ArgumentAccess.singleValue(commandLine, "config"), working); return;
                default: InitializationMessages.inputError("tooManyConfigurations");
            }
        } catch (ArgumentException exception) {
            InitializationMessages.error(exception.getMessage());
        } catch (IOException | SecurityException exception) {
            InitializationMessages.ioError();
        }
    }

    private void applyFile(String name, WorkingArguments working) throws IOException {
        Path file = configurationFile(name);
        Arguments configuration = read(file);
        new TomlConfiguration().apply(configuration, working);
    }

    private Path configurationFile(String name) {
        try {
            Path file = Path.of(name);
            if (!Files.exists(file)) throw new ArgumentException("missingConfigPath");
            if (!Files.isRegularFile(file)) throw new ArgumentException("configNotFile");
            return file;
        } catch (InvalidPathException exception) {
            throw new ArgumentException("invalidPath");
        }
    }

    public Arguments read(Path file) throws IOException {
        return new TomlConfiguration().read(file);
    }
}
