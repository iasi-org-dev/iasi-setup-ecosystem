package org.iasi.setupdev.configuration;

import java.io.IOException;
import java.io.InputStream;
import java.io.FilterInputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.temporal.TemporalAccessor;
import java.util.ArrayList;
import org.iasi.setupdev.args.ArgumentException;
import org.iasi.setupdev.args.Arguments;
import org.iasi.setupdev.args.WorkingArguments;
import org.tomlj.Toml;
import org.tomlj.TomlArray;
import org.tomlj.TomlParseResult;

/**
 * Reads TOML sources into textual arguments and applies the same layer rules to internal and external configuration.
 *
 * @author Javier G. Grandez
 * @since 0.1.0
 * @version 0.1.0
 * @history 2026-11-20 | 0.1.0 | Share TOML parsing and layer application across file and resource sources.
 */
public final class TomlConfiguration {
    public Arguments read(Path file) throws IOException {
        try (var stream = Files.newInputStream(file)) {
            return read(stream);
        }
    }

    /**
     * Reads a borrowed stream without closing it; ownership remains with the source layer.
     *
     * @param stream UTF-8 TOML source
     * @return textual scalar or list values awaiting final validation
     * @throws IOException if the source cannot be read
     */
    public Arguments read(InputStream stream) throws IOException {
        TomlParseResult document = Toml.parse(new BorrowedStream(stream));
        checkSyntax(document);
        return loadArguments(document);
    }

    public void apply(Arguments configuration, WorkingArguments working) {
        for (int index = 0; index < configuration.getParameters().size(); index++) {
            String name = configuration.getParameters().get(index);
            if (name.equals("force") || name.equals("autostart") || name.equals("help")) throw new ArgumentException("unknownConfigKey");
            working.setParameter(name, configuration.getParameterValues().get(index));
        }
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

    // TOML strings already retain their literal commas and quote characters.
    private String scalarText(Object value) {
        if (!(value instanceof String || value instanceof Number || value instanceof Boolean || value instanceof TemporalAccessor))
            throw new ArgumentException("invalidConfigType");
        return value.toString();
    }

    /**
     * Prevents the TOML parser from closing a stream owned by its source layer.
     *
     * @author Javier G. Grandez
     * @since 0.1.0
     * @version 0.1.0
     * @history 2026-11-20 | 0.1.0 | Preserve source-layer ownership during TOML parsing.
     */
    private static final class BorrowedStream extends FilterInputStream {
        private BorrowedStream(InputStream stream) {
            super(stream);
        }

        /**
         * Leaves the borrowed stream open; the layer that acquired it performs closure.
         */
        @Override
        public void close() {
        }
    }
}
