package org.iasi.setupdev.args;

import static org.junit.jupiter.api.Assertions.*;

import java.util.List;
import org.junit.jupiter.api.Test;

class WorkingArgumentsTest {
    @Test
    void updatesExistingValueWithoutAddingPendingEntry() {
        WorkingArguments working = new WorkingArguments();
        working.setParameter("logs", List.of("from-toml"));
        working.setArgument("LOGS", "from-environment");
        assertEquals("from-environment", working.singleValues().get("logs"));
        assertTrue(working.getPendingNames().isEmpty());
    }

    @Test
    void retainsNewValuesUnclassifiedUntilResolved() {
        WorkingArguments working = new WorkingArguments();
        working.setArgument("LOGS", "from-environment");
        assertEquals(List.of("LOGS"), working.getPendingNames());
        assertEquals(List.of("from-environment"), working.getPendingValues());
        assertTrue(working.getParameters().isEmpty());
        assertTrue(working.getFlags().isEmpty());
        assertTrue(working.getDefines().isEmpty());
    }

    @Test
    void preservesFlagValuesAsTextAndReplacesPreviousClassification() {
        WorkingArguments working = new WorkingArguments();
        working.setParameter("verbose", List.of("incorrecto"));
        working.setFlag("verbose", "3");
        working.setFlag("autostart", "false");
        assertTrue(working.getParameters().isEmpty());
        assertEquals("3", working.singleValues().get("verbose"));
        assertEquals("false", working.singleValues().get("autostart"));
    }

    @Test
    void resolvesEnvironmentNamesUsingTheirDeclaredCategory() {
        ArgsList definitions = new ArgsList()
            .add(new ARG("v",       "VERBOSE", ArgType.FLAG, ArgClass.NATURAL))
            .add(new ARG("verbose", "VERBOSE", ArgType.DEF,  ArgClass.INTEGER))
            .add(new ARG("logs",    "LOGS",    ArgType.PARM, ArgClass.DIRECTORY));
        assertEquals(ArgType.DEF, definitions.getByEnvironment("VERBOSE").getArgType());
        assertEquals(ArgType.PARM, definitions.getByEnvironment("LOGS").getArgType());
        assertNull(definitions.getByEnvironment("UNKNOWN"));
    }
}
