package org.iasi.args;

import org.iasi.args.model.*;
import org.iasi.args.loader.*;
import org.iasi.args.layer.*;
import org.iasi.args.validation.*;
import static org.junit.jupiter.api.Assertions.*;

import java.io.IOException;
import java.math.BigDecimal;
import java.net.URI;
import java.util.Map;
import org.junit.jupiter.api.Test;

/**
 * Checks argument constructors, accepted names and environment binding declarations.
 *
 * @author Javier G. Grandez
 * @since 0.1.0
 * @version 0.1.0
 * @history 2026-11-19 | 0.1.0 | Establish structural documentation and component responsibilities.
 */
class ArgsListTest {
    @Test
    void collectsEnvironmentNamesFromEveryArgumentKind() {
        ArgsList definitions = new ArgsList()
            .add(new ARG("v",       "verbose", ArgType.FLAG,   ArgClass.NATURAL))
            .add(new ARG("V",       "VERBOSE", ArgType.FLAG,   ArgClass.NATURAL))
            .add(new ARG("logs",    "logs",    ArgType.PARM,   ArgClass.DIRECTORY))
            .add(new ARG("mode",    "MODE",    ArgType.DEF,    ArgClass.STRING))
            .add(new ARG("targets", "TARGETS", ArgType.TARGET, ArgClass.STRING))
            .add(new ARG("h",        null,     ArgType.FLAG,   ArgClass.BOOLEAN));
        assertEquals(java.util.List.of("VERBOSE", "LOGS", "MODE"), definitions.getEnvironmentNames());
    }

    @Test
    void constructorsPreserveArgumentKindAndDataClass() {
        ARG flag = new ARG("h", null, ArgType.FLAG);
        ARG file = new ARG("config", null, ArgType.PARM, ArgClass.FILE, false, false, true);
        assertEquals(ArgType.FLAG, flag.getArgType());
        assertEquals(ArgClass.BOOLEAN, flag.getArgClass());
        assertEquals(ArgType.PARM, file.getArgType());
        assertEquals(ArgClass.FILE, file.getArgClass());
        assertTrue(file.isRequired());
    }

    @Test
    void suppliedDefinitionsControlTheParser() {
        ArgsList definitions = new ArgsList().add(new ARG("a", null, ArgType.FLAG));
        assertEquals(java.util.List.of("a"), new CommandLineLoader("-a").getFlags());
        assertThrows(ArgumentException.class, () -> new ArgumentDefinitionsValidator().validateArguments(new CommandLineLoader("-f"), definitions));
    }

    @Test
    void repeatedVerbosityFlagsPreserveTheirOrder() {
        assertEquals(java.util.List.of("v", "s", "V"), new CommandLineLoader("-v", "-s", "-V").getFlags());
        assertEquals(java.util.List.of("V", "s"), new CommandLineLoader("-Vs").getFlags());
    }

    @Test
    void convertsDeclaredTypesAndChecksRanges() throws IOException {
        ArgsList definitions = new ArgsList()
            .add(new ARG("count", null, ArgType.DEF, ArgClass.NATURAL, true, false, false, 1L, 5L))
            .add(new ARG("ratio", null, ArgType.DEF, ArgClass.FLOAT))
            .add(new ARG("uri",   null, ArgType.DEF, ArgClass.URL));
        ArgumentValidator validator = new ArgumentValidator(definitions);
        var values = validator.validateArgs(Map.of("count", "2", "ratio", "1.5", "uri", "urn:iasi:test"));
        assertEquals(2, values.get("count"));
        assertEquals(new BigDecimal("1.5"), values.get("ratio"));
        assertEquals(URI.create("urn:iasi:test"), values.get("uri"));
        assertThrows(ArgumentException.class, () -> validator.validateArgs(Map.of("count", "0")));
        assertThrows(ArgumentException.class, () -> validator.validateArgs(Map.of("count", "6")));
        assertThrows(ArgumentException.class, () -> validator.validateArgs(Map.of()));
    }
}
