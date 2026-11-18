package org.iasi.setupdev.configuration;

import java.io.IOException;
import java.nio.file.Path;
import java.time.temporal.TemporalAccessor;
import java.util.ArrayList;
import org.iasi.setupdev.args.ArgumentException;
import org.iasi.setupdev.args.Arguments;
import org.iasi.setupdev.args.ArgumentAccess;
import org.iasi.setupdev.args.WorkingArguments;
import org.iasi.setupdev.messages.InitializationMessages;
import java.nio.file.Files;
import java.nio.file.InvalidPathException;
import org.tomlj.Toml;
import org.tomlj.TomlArray;
import org.tomlj.TomlParseResult;

public final class ExternalConfiguration {
    public void apply(Arguments commandLine, WorkingArguments working) {
        try {
            switch (commandLine.count("config")) {
                case 0: return;
                case 1: applyFile(ArgumentAccess.singleValue(commandLine, "config"), working); return;
                default: InitializationMessages.inputError("tooManyConfigurations");
            }
        } catch (ArgumentException exception) {
            InitializationMessages.inputError(exception.getMessage());
        } catch (IOException | SecurityException exception) {
            InitializationMessages.ioError();
        }
    }

    private void applyFile(String name, WorkingArguments working) throws IOException {
        Path file = configurationFile(name);
        Arguments configuration = read(file);
        applyValues(configuration, working);
    }

    private Path configurationFile(String name) {
        try {
            Path file = Path.of(name);
            if (!Files.isRegularFile(file)) throw new ArgumentException("invalidPath");
            return file;
        } catch (InvalidPathException exception) {
            throw new ArgumentException("invalidPath");
        }
    }

    private void applyValues(Arguments configuration, WorkingArguments working) {
        for (int index = 0; index < configuration.getParameters().size(); index++) {
            String name = configuration.getParameters().get(index);
            if (name.equals("force") || name.equals("autostart") || name.equals("help")) throw new ArgumentException("unknownConfigKey");
            working.setParameter(name, configuration.getParameterValues().get(index));
        }
    }

    public Arguments read(Path file) throws IOException {
        TomlParseResult document = Toml.parse(file);
        checkSyntax(document);
        return loadArguments(document);
    }

    private void checkSyntax(TomlParseResult document) {
        if (document.hasErrors()) throw new ArgumentException("invalidToml");
    }

    private Arguments loadArguments(TomlParseResult document) {
        Arguments arguments = new Arguments();
        for (String name : document.keySet()) {
            ArrayList<String> values = loadValues(document.get(java.util.List.of(name)));
            arguments.getParameters().add(name);
            arguments.getParameterValues().add(values);
        }
        return arguments;
    }

    private ArrayList<String> loadValues(Object value) {
        ArrayList<String> values = new ArrayList<>();
        if (value instanceof TomlArray array) {
            for (int index = 0; index < array.size(); index++)
                values.add(scalarText(array.get(index)));
        } else values.add(scalarText(value));
        return values;
    }

    // Las comas y comillas de un string TOML ya fueron interpretadas por su parser.
    private String scalarText(Object value) {
        if (!(value instanceof String || value instanceof Number || value instanceof Boolean || value instanceof TemporalAccessor))
            throw new ArgumentException("invalidConfigType");
        return value.toString();
    }
}
