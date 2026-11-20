package org.iasi.base;

import static org.junit.jupiter.api.Assertions.*;

import java.lang.reflect.Modifier;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;

/**
 * Checks the return-code bit contract and its independence from execution decisions.
 *
 * @author Javier G. Grandez
 * @since 0.1.0
 * @version 0.1.0
 * @history 2026-11-19 | 0.1.0 | Establish structural documentation and component responsibilities.
 */
class RCTest {

    @ParameterizedTest
    @CsvSource({"OK,0", "NOTHING_TO_DO,1", "INFO,2", "WARNING,4", "ATTENTION,8", "ERROR,16", "SEVERE,32", "FATAL,64"})
    void constantsMatchStandard(String name, int expected) throws Exception {
        var field = RC.class.getField(name);
        assertEquals(int.class, field.getType());
        assertTrue(Modifier.isStatic(field.getModifiers()) && Modifier.isFinal(field.getModifiers()));
        assertEquals(expected, field.getInt(null));
        assertFalse(RC.class.isEnum());
        assertEquals(8, RC.class.getFields().length);
    }

    @Test
    void masksAndReservedBitsAreClassifiedWithoutEnums() {
        for (int rc = 0; rc <= 0x7F; rc++) {
            assertTrue(RC.isValid(rc));
            assertEquals(rc > 15, RC.isError(rc));
        }
        assertFalse(RC.isValid(-1));
        assertFalse(RC.isValid(0x80));
        assertFalse(RC.isValid(0x100));
        assertEquals(6, RC.INFO | RC.WARNING);
        assertEquals(20, RC.ERROR | RC.WARNING);
    }
}
