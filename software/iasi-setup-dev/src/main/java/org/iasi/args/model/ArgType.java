package org.iasi.args.model;

import org.iasi.args.loader.*;
import org.iasi.args.layer.*;
import org.iasi.args.validation.*;
/**
 * Distinguishes flags, named parameters, definitions and positional targets.
 *
 * @author Javier G. Grandez
 * @since 0.1.0
 * @version 0.1.0
 * @history 2026-11-19 | 0.1.0 | Establish structural documentation and component responsibilities.
 */
public enum ArgType {
    FLAG, PARM, DEF, TARGET
}
