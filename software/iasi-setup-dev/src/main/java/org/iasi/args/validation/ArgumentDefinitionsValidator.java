package org.iasi.args.validation;

import org.iasi.args.access.ArgumentAccess;
import org.iasi.args.model.*;
import org.iasi.args.loader.*;
import org.iasi.args.layer.*;
/**
 * Checks loaded CLI names and multiplicity against the declarations accepted by the application.
 *
 * @author Javier G. Grandez
 * @since 0.1.0
 * @version 0.1.0
 * @history 2026-11-19 | 0.1.0 | Establish structural documentation and component responsibilities.
 */
public final class ArgumentDefinitionsValidator {
    public void validateArguments(Arguments arguments, ArgsList definitions) {
        validateFlags(arguments, definitions);
        validateParameters(arguments, definitions);
    }

    private void validateFlags(Arguments arguments, ArgsList definitions) {
        for (String flag : arguments.getFlags()) {
            ARG definition = definitions.get(flag);
            if (definition == null || definition.getArgType() != ArgType.FLAG) throw new ArgumentException("unknownFlag");
        }
    }

    private void validateParameters(Arguments arguments, ArgsList definitions) {
        for (int index = 0; index < arguments.getParameters().size(); index++) {
            String name = arguments.getParameters().get(index);
            ARG definition = definitions.get(name);
            if (definition == null || definition.getArgType() != ArgType.PARM) throw new ArgumentException("unknownParameter");
            if (!definition.isMultiple()) ArgumentAccess.singleValue(arguments, name);
        }
    }
}
