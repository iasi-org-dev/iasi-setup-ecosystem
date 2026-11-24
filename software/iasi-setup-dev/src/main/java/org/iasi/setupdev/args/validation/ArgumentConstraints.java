package org.iasi.setupdev.args.validation;

import org.iasi.setupdev.args.model.*;
import org.iasi.setupdev.args.loader.*;
import org.iasi.setupdev.args.layer.*;
import java.io.IOException;
import java.nio.file.Path;
import java.util.List;
import org.iasi.common.validation.PathValidation;
import org.iasi.common.validation.ValueConstraintException;
import org.iasi.common.validation.ValueConstraints;

/**
 * Applies ARG constraints using reusable numeric and filesystem validation services.
 *
 * @author Javier G. Grandez
 * @since 0.1.0
 * @version 0.1.0
 * @history 2026-11-19 | 0.1.0 | Establish structural documentation and component responsibilities.
 */
public final class ArgumentConstraints {
    public void check(ARG definition, Object value) {
        if (value instanceof List<?> values) {
            for (Object item : values) check(definition, item);
        } else if (value instanceof Number number) checkRange(definition, number);
        else if (value instanceof Path path) checkPath(definition, path);
    }

    public void prepare(ARG definition, Object value) throws IOException {
        if (value instanceof List<?> values) {
            for (Object item : values) prepare(definition, item);
        } else if (value instanceof Path path)
            PathValidation.prepare(path, definition.getArgClass() == ArgClass.DIRECTORY, definition.isRequired());
    }

    private void checkRange(ARG definition, Number value) {
        try {
            ValueConstraints.checkRange(value, definition.getMinimum(), definition.getMaximum());
        } catch (ValueConstraintException exception) {
            throw new ArgumentException("invalidRange");
        }
    }

    private void checkPath(ARG definition, Path value) {
        try {
            PathValidation.check(value, definition.getArgClass() == ArgClass.DIRECTORY, definition.isRequired());
        } catch (ValueConstraintException exception) {
            throw new ArgumentException("invalidPath");
        }
    }
}
