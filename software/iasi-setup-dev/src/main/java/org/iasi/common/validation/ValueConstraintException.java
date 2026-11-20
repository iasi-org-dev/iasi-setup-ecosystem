package org.iasi.common.validation;

/**
 * Distinguishes a violated value constraint from an unparseable lexical value.
 *
 * @author Javier G. Grandez
 * @since 0.1.0
 * @version 0.1.0
 * @history 2026-11-19 | 0.1.0 | Establish structural documentation and component responsibilities.
 */
public final class ValueConstraintException extends IllegalArgumentException {
    public ValueConstraintException(String message) {
        super(message);
    }
}
