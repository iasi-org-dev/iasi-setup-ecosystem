package org.iasi.setupdev.configuration;

import static org.junit.jupiter.api.Assertions.*;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.List;
import org.iasi.setupdev.args.ArgumentAccess;
import org.iasi.setupdev.args.ArgumentException;
import org.iasi.setupdev.args.CommandLineLoader;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

class ExternalConfigurationTest {
    @TempDir
    Path directory;

    @Test
    void loadsScalarsAndArraysAsStringValues() throws IOException {
        Path file = directory.resolve("settings.toml");
        Files.writeString(file, """
                logs = "carpeta con espacios,y coma"
                verbose = 2
                servers = ["uno", "dos,tres"]
                """);
        var arguments = new ExternalConfiguration().read(file);
        assertEquals(List.of("carpeta con espacios,y coma"), ArgumentAccess.values(arguments, "logs"));
        assertEquals(List.of("2"), ArgumentAccess.values(arguments, "verbose"));
        assertEquals(List.of("uno", "dos,tres"), ArgumentAccess.values(arguments, "servers"));
    }

    @Test
    void rejectsMalformedTomlBeforeReturningArguments() throws IOException {
        Path file = directory.resolve("invalid.toml");
        Files.writeString(file, "logs = [");
        ArgumentException error = assertThrows(ArgumentException.class, () -> new ExternalConfiguration().read(file));
        assertEquals("invalidToml", error.getMessage());
    }

    @Test
    void countsConfigValuesAcrossOccurrencesAndCommaLists() {
        var arguments = new CommandLineLoader("--config", "uno.toml,dos.toml", "--config", "tres.toml");
        assertEquals(3, arguments.count("config"));
        assertEquals(List.of("uno.toml", "dos.toml", "tres.toml"), ArgumentAccess.values(arguments, "config"));
    }
}
