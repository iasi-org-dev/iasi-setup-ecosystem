package org.iasi.common.validation;

import static org.junit.jupiter.api.Assertions.*;

import java.net.URI;
import java.time.LocalDate;
import org.junit.jupiter.api.Test;

/**
 * Checks numeric, calendar, URI and email conversion boundaries using application-independent services.
 *
 * @author Javier G. Grandez
 * @since 0.1.0
 * @version 0.1.0
 * @history 2026-11-19 | 0.1.0 | Establish structural documentation and component responsibilities.
 */
class ValueConversionTest {
    @Test
    void distinguishesNaturalConstraintsFromInvalidIntegers() {
        assertEquals(3, ValueConversion.toNatural("3"));
        assertThrows(ValueConstraintException.class, () -> ValueConversion.toNatural("0"));
        assertThrows(ValueConstraintException.class, () -> ValueConversion.toNatural("-1"));
        assertThrows(NumberFormatException.class, () -> ValueConversion.toInteger("1.5"));
        assertThrows(NumberFormatException.class, () -> ValueConversion.toInteger("2147483648"));
    }

    @Test
    void checksCalendarDatesAndEmailValues() {
        assertEquals(LocalDate.of(2024, 2, 29), ValueConversion.toDate("2024-02-29"));
        assertThrows(java.time.DateTimeException.class, () -> ValueConversion.toDate("2025-02-29"));
        assertEquals("user@example.com", ValueConversion.toMail("user@example.com"));
        assertThrows(IllegalArgumentException.class, () -> ValueConversion.toMail("invalid"));
        assertThrows(IllegalArgumentException.class, () -> ValueConversion.toMail("user name@example.com"));
    }

    @Test
    void acceptsAbsoluteUrisAndStrictBooleans() {
        assertEquals(URI.create("urn:iasi:test"), ValueConversion.toUri("urn:iasi:test"));
        assertThrows(IllegalArgumentException.class, () -> ValueConversion.toUri("relative/path"));
        assertFalse(ValueConversion.toBoolean("false"));
        assertThrows(IllegalArgumentException.class, () -> ValueConversion.toBoolean("yes"));
    }
}
