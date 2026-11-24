package org.iasi.args.model;

import org.iasi.args.loader.*;
import org.iasi.args.layer.*;
import org.iasi.args.validation.*;
import lombok.Getter;

/**
 * Declares the immutable identity, data class and constraints of one supported argument.
 *
 * @author Javier G. Grandez
 * @since 0.1.0
 * @version 0.1.0
 * @history 2026-11-19 | 0.1.0 | Establish structural documentation and component responsibilities.
 */
@Getter
public final class ARG {
    private final String   cli;
    private final String   env;
    private final ArgClass argClass;
    private final ArgType  argType;
    private final boolean  mandatory;
    private final boolean  multiple;
    private final boolean  required;
    private final Long     minimum;
    private final Long     maximum;

    public ARG(String cli, String env) {
        this(cli, env, ArgType.PARM, ArgClass.STRING);
    }

    public ARG(String cli, String env, ArgType argType) {
        this(cli, env, argType, argType == ArgType.FLAG ? ArgClass.BOOLEAN : ArgClass.STRING);
    }

    public ARG(String cli, String env, ArgClass argClass) {
        this(cli, env, ArgType.PARM, argClass);
    }

    public ARG(String cli, String env, ArgType argType, ArgClass argClass) {
        this(cli, env, argType, argClass, false, false, false);
    }

    public ARG(String cli, String env, ArgType argType, ArgClass argClass,
               boolean mandatory, boolean multiple, boolean required) {
        this(cli, env, argType, argClass, mandatory, multiple, required, null, null);
    }

    public ARG(String cli, String env, ArgType argType, ArgClass argClass,
               boolean mandatory, boolean multiple, boolean required, Long minimum, Long maximum) {
        this.cli       = cli;
        this.env       = env;
        this.argClass  = argClass;
        this.argType   = argType;
        this.mandatory = mandatory;
        this.multiple  = multiple;
        this.required  = required;
        this.minimum   = minimum;
        this.maximum   = maximum;
    }
}
