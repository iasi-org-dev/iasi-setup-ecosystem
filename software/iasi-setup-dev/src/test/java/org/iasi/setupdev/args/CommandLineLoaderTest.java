package org.iasi.setupdev.args;

import static org.junit.jupiter.api.Assertions.*;

import java.util.List;
import org.junit.jupiter.api.Test;

/**
 * Checks syntax-only token loading, indexed occurrences and surviving quote boundaries.
 *
 * @author Javier G. Grandez
 * @since 0.1.0
 * @version 0.1.0
 * @history 2026-11-19 | 0.1.0 | Establish structural documentation and component responsibilities.
 */
class CommandLineLoaderTest {
    @Test
    void separatesGroupedFlagsParametersAndTargets() {
        Arguments arguments = new CommandLineLoader(
                "-afV", "iasi-models", "--servers", "uno,dos", "iasi-dev-.*");
        assertEquals(List.of("a", "f", "V"), arguments.getFlags());
        assertEquals(List.of("servers"), arguments.getParameters());
        assertEquals(List.of(List.of("uno", "dos")), arguments.getParameterValues());
        assertEquals(List.of("iasi-models", "iasi-dev-.*"), arguments.getTargets());
        assertTrue(arguments.getDefines().isEmpty());
        assertTrue(arguments.getDefineValues().isEmpty());
    }

    @Test
    void preservesParameterOccurrencesByIndex() {
        Arguments arguments = new CommandLineLoader("--server", "uno", "--server", "dos,tres");
        assertEquals(List.of("server", "server"), arguments.getParameters());
        assertEquals(List.of(List.of("uno"), List.of("dos", "tres")), arguments.getParameterValues());
    }

    @Test
    void respectsLiteralQuotesAndOppositeQuotesInsideValues() {
        Arguments arguments = new CommandLineLoader(
                "--values", "uno,'dos,tres',\"cuatro cinco\",'seis\"siete',\"ocho'nueve\"");
        assertEquals(List.of("uno", "dos,tres", "cuatro cinco", "seis\"siete", "ocho'nueve"),
                arguments.getParameterValues().getFirst());
    }

    @Test
    void loadsUnknownArgumentsWithoutConsultingDefinitions() {
        Arguments arguments = new CommandLineLoader("-xyz", "--unknown", "value");
        assertEquals(List.of("x", "y", "z"), arguments.getFlags());
        assertEquals(List.of("unknown"), arguments.getParameters());
    }

    @Test
    void rejectsEmptyPrefixesAndMissingOrPrefixedValues() {
        assertThrows(ArgumentException.class, () -> loadSyntax("-"));
        assertThrows(ArgumentException.class, () -> loadSyntax("--"));
        assertThrows(ArgumentException.class, () -> loadSyntax("--name"));
        for (String value : List.of("", " ", "-", "--", "-v", "--other"))
            assertThrows(ArgumentException.class, () -> loadSyntax("--name", value));
    }

    @Test
    void rejectsUnclosedQuotesAndEmptyListElements() {
        for (String value : List.of("'unclosed", "\"unclosed", "a,,b", "a,", ",a"))
            assertThrows(ArgumentException.class, () -> loadSyntax("--name", value));
    }
    private Arguments loadSyntax(String... tokens) {
        Arguments arguments = new Arguments();
        CommandLineLoader.loadTokens(arguments, tokens);
        return arguments;
    }
}
