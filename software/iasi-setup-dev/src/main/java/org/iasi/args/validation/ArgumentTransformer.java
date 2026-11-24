package org.iasi.args.validation;

import org.iasi.args.model.*;
import org.iasi.args.loader.*;
import org.iasi.args.layer.*;
import java.time.DateTimeException;
import org.iasi.common.validation.ValueConversion;
import org.iasi.common.validation.ValueConstraintException;

/**
 * Selects reusable text conversions from ARG metadata and translates conversion failures to diagnostic keys.
 *
 * @author Javier G. Grandez
 * @since 0.1.0
 * @version 0.1.0
 * @history 2026-11-19 | 0.1.0 | Establish structural documentation and component responsibilities.
 */
public final class ArgumentTransformer {
    public Object transform(ARG definition, String value) {
        if (value.isBlank()) throw new ArgumentException("missingValue");
        try {
            return switch (definition.getArgClass()) {
                case STRING -> value;
                case BOOLEAN -> ValueConversion.toBoolean(value);
                case INTEGER -> ValueConversion.toInteger(value);
                case NATURAL -> ValueConversion.toNatural(value);
                case FLOAT -> ValueConversion.toFloat(value);
                case FILE, DIRECTORY -> ValueConversion.toPath(value);
                case URL -> ValueConversion.toUri(value);
                case MAIL -> ValueConversion.toMail(value);
                case DATE -> ValueConversion.toDate(value);
                case TIME -> ValueConversion.toTime(value);
                case TMS -> ValueConversion.toTimestamp(value);
            };
        } catch (ValueConstraintException exception) {
            throw new ArgumentException("invalidRange");
        } catch (IllegalArgumentException | DateTimeException exception) {
            throw new ArgumentException("invalidConfigType");
        }
    }
}
