package org.iasi.setupdev.args.validation;

import org.iasi.setupdev.args.model.*;
import org.iasi.setupdev.args.loader.*;
import org.iasi.setupdev.args.layer.*;
/**
 * Carries a controlled diagnostic key for an invalid application argument.
 *
 * @author Javier G. Grandez
 * @since 0.1.0
 * @version 0.1.0
 * @history 2026-11-19 | 0.1.0 | Establish structural documentation and component responsibilities.
 */
public final class ArgumentException extends IllegalArgumentException {

    public ArgumentException(String key) {
        super(key);
    }
}
