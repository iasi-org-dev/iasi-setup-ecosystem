package org.iasi.common.validation;

import java.math.BigDecimal;

/**
 * Checks numeric bounds and positive-integer constraints independently of CLI definitions.
 *
 * @author Javier G. Grandez
 * @since 0.1.0
 * @version 0.1.0
 * @history 2026-11-19 | 0.1.0 | Establish structural documentation and component responsibilities.
 */
public final class ValueConstraints {
    private ValueConstraints() {
    }

    public static void requirePositive(int value) {
        if (value <= 0) throw new ValueConstraintException("Expected a positive integer");
    }

    public static void checkRange(Number value, Long minimum, Long maximum) {
        BigDecimal number = new BigDecimal(value.toString());
        if (minimum != null && number.compareTo(BigDecimal.valueOf(minimum)) < 0) throw new ValueConstraintException("Below minimum");
        if (maximum != null && number.compareTo(BigDecimal.valueOf(maximum)) > 0) throw new ValueConstraintException("Above maximum");
    }
}
