package org.iasi.setupdev.args;

/**
 * Comprueba los argumentos cargados contra el esquema, fuera del loader sintáctico.
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
