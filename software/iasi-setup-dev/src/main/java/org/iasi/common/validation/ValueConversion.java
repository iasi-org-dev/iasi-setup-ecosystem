package org.iasi.common.validation;

import java.math.BigDecimal;
import java.net.URI;
import java.nio.file.Path;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;

/**
 * Converts textual values to reusable Java types, using ISO date and time formats.
 *
 * @author Javier G. Grandez
 * @since 0.1.0
 * @version 0.1.0
 * @history 2026-11-19 | 0.1.0 | Establish structural documentation and component responsibilities.
 */
public final class ValueConversion {
    private ValueConversion() {
    }

    public static boolean toBoolean(String value) {
        if (!value.equalsIgnoreCase("true") && !value.equalsIgnoreCase("false")) throw new IllegalArgumentException("Expected a boolean");
        return Boolean.parseBoolean(value);
    }

    public static int toInteger(String value) {
        return Integer.parseInt(value);
    }

    public static int toNatural(String value) {
        int number = toInteger(value);
        ValueConstraints.requirePositive(number);
        return number;
    }

    public static BigDecimal toFloat(String value) {
        return new BigDecimal(value);
    }

    public static Path toPath(String value) {
        return Path.of(value).toAbsolutePath().normalize();
    }

    public static URI toUri(String value) {
        URI uri = URI.create(value);
        if (!uri.isAbsolute()) throw new IllegalArgumentException("Expected an absolute URI");
        return uri;
    }

    public static String toMail(String value) {
        if (!value.matches("[^\\s@]+@[^\\s@]+\\.[^\\s@]+")) throw new IllegalArgumentException("Expected an email address");
        return value;
    }

    public static LocalDate toDate(String value) {
        return LocalDate.parse(value);
    }

    public static LocalTime toTime(String value) {
        return LocalTime.parse(value);
    }

    public static LocalDateTime toTimestamp(String value) {
        return LocalDateTime.parse(value);
    }
}
