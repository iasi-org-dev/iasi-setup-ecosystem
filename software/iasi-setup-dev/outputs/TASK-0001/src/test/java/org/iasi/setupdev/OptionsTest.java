package org.iasi.setupdev;

import static org.junit.jupiter.api.Assertions.*;

import java.util.List;
import org.iasi.common.logging.Verbosity;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;
import org.junit.jupiter.params.provider.ValueSource;

class OptionsTest {
    /**
     * Comprueba secuencias y grupos donde la última selección determina la consola.
     */
    @ParameterizedTest
    @CsvSource({"-v -s -V,VERY_VERBOSE", "-V -s,SILENT", "-vsV,VERY_VERBOSE", "-Vsv,VERBOSE", "-svf,VERBOSE", "-vVs,SILENT"})
    void lastVerbosityWins(String arguments, Verbosity expected) {
        assertEquals(expected, Options.parse(arguments.split(" ")).verbosity());
    }

    /**
     * Evita que force aparezca habilitado por defecto o pierda el efecto explícito
     * de -f.
     */
    @Test
    void forceIsHardcodedFalseAndOnlyFlagEnablesIt() {
        assertFalse(Options.parse().force());
        assertTrue(Options.parse("platform", "-vf").force());
        assertTrue(Options.parse("-sfV").force());
    }

    /** Rechaza flags y parámetros no declarados sin introducir alias implícitos. */
    @ParameterizedTest
    @ValueSource(strings = {"--help", "--log", "--unknown", "--logs=x", "-F", "-H", "-x", "-"})
    void invalidOptions(String token) {
        assertThrows(InputException.class, () -> Options.parse(token));
    }

    /**
     * Verifica valores separados, rutas con espacios, tokens con guion y
     * repeticiones.
     */
    @Test
    void parameterValuesAreSingleLiteralTokens() {
        assertThrows(InputException.class, () -> Options.parse("--config"));
        assertThrows(InputException.class, () -> Options.parse("--logs", ""));
        assertEquals("-v", Options.parse("--logs", "-v").parameters().get("--logs"));
        assertEquals("two words", Options.parse("--definitions", "two words").parameters().get("--definitions"));
        assertEquals("last", Options.parse("--machines", "first", "--machines", "last").parameters().get("--machines"));
    }

    /** Comprueba posiciones no ambiguas sin perder el orden de los flags. */
    @Test
    void flagsAndParametersMaySurroundCommand() {
        Options options = Options.parse("-v", "--logs", "audit", "platform", "-sVf");
        assertEquals(List.of("platform"), options.words());
        assertEquals(Verbosity.VERY_VERBOSE, options.verbosity());
        assertTrue(options.force());
    }

    /**
     * Rechaza combinaciones ambiguas o incompletas antes de ejecutar operaciones.
     */
    @ParameterizedTest
    @ValueSource(strings = {"", "help workflow", "workflow", "other", "platform target", "-h", "workflow -h"})
    void incompleteAndUnknownCommandsFail(String input) {
        String[] arguments = input.isEmpty() ? new String[0] : input.split(" ");
        assertThrows(InputException.class, () -> Command.resolve(Options.parse(arguments).words()));
    }
}
