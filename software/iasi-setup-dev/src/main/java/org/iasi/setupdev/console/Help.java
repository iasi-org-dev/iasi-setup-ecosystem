package org.iasi.setupdev.console;

import java.io.PrintStream;
import java.io.IOException;
import java.util.Locale;
import java.util.Properties;
import org.iasi.common.i18n.MessageCatalog;

/**
 * Renders localized CLI help as plain text, preserving spacing and obtaining its version from build metadata.
 *
 * @author Javier G. Grandez
 * @since 0.1.0
 * @version 0.1.0
 * @history 2026-11-19 | 0.1.0 | Establish structural documentation and component responsibilities.
 */
public final class Help {
    private final MessageCatalog catalog;

    public Help() {
        this(Locale.getDefault());
    }

    Help(Locale locale) {
        catalog = new MessageCatalog("messages", locale);
    }

    /**
     * Writes plain help text without logging prefixes or colors and leaves the caller-owned stream open.
     * @param out destination for help text
     */
    public void show(PrintStream out) {
        out.println(catalog.text("help.title", version()));
        out.println(catalog.text("help.description"));
        out.println();
        showSection(out, "help.general");
        showSection(out, "help.flags");
        showSection(out, "help.parameters");
        showSection(out, "help.targets");
        showSection(out, "help.defaults");
        showSection(out, "help.configuration");
    }

    private void showSection(PrintStream out, String key) {
        out.println(catalog.text(key));
        out.println();
    }

    private String version() {
        Properties properties = new Properties();
        try (var resource = Help.class.getResourceAsStream("/version.properties")) {
            if (resource == null) throw new IllegalStateException("Missing build version");
            properties.load(resource);
            return properties.getProperty("version");
        } catch (IOException exception) {
            throw new IllegalStateException("Cannot read build version", exception);
        }
    }
}
