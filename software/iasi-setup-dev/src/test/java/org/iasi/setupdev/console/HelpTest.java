package org.iasi.setupdev.console;

import static org.junit.jupiter.api.Assertions.*;

import java.io.ByteArrayOutputStream;
import java.io.PrintStream;
import java.nio.charset.StandardCharsets;
import java.nio.file.Path;
import java.util.Locale;
import javax.xml.parsers.DocumentBuilderFactory;
import org.junit.jupiter.api.Test;

/**
 * Checks exact localized help layout, build-version reporting and the absence of operational prefixes.
 *
 * @author Javier G. Grandez
 * @since 0.1.0
 * @version 0.1.0
 * @history 2026-11-19 | 0.1.0 | Establish structural documentation and component responsibilities.
 */
class HelpTest {
    @Test
    void matchesSpanishHelpIncludingBlankLinesAndAlignment() throws Exception {
        String expected;
        try (var resource = getClass().getResourceAsStream("help_es.txt")) {
            assertNotNull(resource);
            expected = new String(resource.readAllBytes(), StandardCharsets.UTF_8).replace("@VERSION@", projectVersion());
        }
        assertEquals(expected.replace("\r\n", "\n"), render(Locale.forLanguageTag("es")));
    }

    @Test
    void containsNoOperationalPrefixesColorsOrUnsupportedAliases() {
        String help = render(Locale.forLanguageTag("es"));
        assertFalse(help.contains("\u001b"));
        assertFalse(help.contains("--help"));
        for (String line : help.lines().toList()) {
            assertFalse(line.matches("^\\d{2}:\\d{2}:\\d{2}.*"), line);
            assertFalse(line.matches("^[A-Z]{3}\\d{5}.*"), line);
            assertFalse(line.matches("^(INFO|WARNING|ERROR|DEBUG|TRACE)\\b.*"), line);
            assertFalse(line.startsWith(" - "), line);
        }
    }

    @Test
    void englishHelpUsesTheSameBuildVersionAndSectionStructure() throws Exception {
        String help = render(Locale.ENGLISH);
        assertTrue(help.startsWith("IASI Setup Dev " + projectVersion() + "\n"));
        for (String heading : new String[]{"USAGE", "FLAGS", "PARAMETERS", "TARGETS", "DEFAULT VALUES", "CONFIGURATION"})
            assertTrue(help.contains("\n\n" + heading + "\n"), heading);
    }

    private String render(Locale locale) {
        var buffer = new ByteArrayOutputStream();
        new Help(locale).show(new PrintStream(buffer, true, StandardCharsets.UTF_8));
        return buffer.toString(StandardCharsets.UTF_8).replace("\r\n", "\n");
    }

    private String projectVersion() throws Exception {
        var document = DocumentBuilderFactory.newInstance().newDocumentBuilder().parse(Path.of("pom.xml").toFile());
        return document.getDocumentElement().getElementsByTagName("version").item(0).getTextContent().strip();
    }
}
