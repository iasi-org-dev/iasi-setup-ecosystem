package org.iasi.setupdev.args.layer;

import org.iasi.setupdev.args.access.ArgumentAccess;
import org.iasi.setupdev.args.model.*;
import org.iasi.setupdev.args.loader.*;
import org.iasi.setupdev.args.validation.*;
import java.util.List;
import java.util.Locale;
import org.iasi.setupdev.messages.InitializationMessages;

/**
 * Applies explicit CLI values and reconciles remaining environment entries with supported argument declarations.
 *
 * @author Javier G. Grandez
 * @since 0.1.0
 * @version 0.1.0
 * @history 2026-11-19 | 0.1.0 | Establish structural documentation and component responsibilities.
 */
public final class CommandLineArguments {
    private final ArgsList         defs;
    private final WorkingArguments workingArguments;

    public CommandLineArguments(ArgsList defs, WorkingArguments workingArguments) {
        this.defs             = defs;
        this.workingArguments = workingArguments;
    }

    public void apply(Arguments commandLine) {
        try {
            applyParameters(commandLine);
            applyFlags(commandLine);
            applyPendingArguments();
        } catch (ArgumentException exception) {
            InitializationMessages.inputError(exception.getMessage());
        }
    }

    private void applyParameters(Arguments arguments) {
        for (String name : arguments.getParameters()) {
            removePendingArgument(name);
            if (name.equals("config") || name.equals("env")) continue;
            workingArguments.setParameter(name, ArgumentAccess.values(arguments, name));
        }
    }

    private void applyFlags(Arguments arguments) {
        for (String flag : arguments.getFlags()) {
            switch (flag) {
                case "h" -> applyFlag(flag, "help", "true");
                case "f" -> applyFlag(flag, "force", "true");
                case "a" -> applyFlag(flag, "autostart", "true");
                case "v" -> applyFlag(flag, "verbose", "2");
                case "V" -> applyFlag(flag, "verbose", "3");
                case "s" -> applyFlag(flag, "verbose", "0");
            }
        }
    }

    private void applyFlag(String cli, String name, String value) {
        workingArguments.setFlag(name, value);
        workingArguments.removePending(name);
        removePendingArgument(cli);
    }

    private void removePendingArgument(String cli) {
        workingArguments.removePending(cli);
        ARG definition = defs.get(cli);
        if (definition != null) workingArguments.removePending(definition.getEnv());
    }

    private void applyPendingArguments() {
        for (String name : List.copyOf(workingArguments.getPendingNames()))
            applyPendingArgument(name);
    }

    private void applyPendingArgument(String name) {
        ARG definition = defs.getByEnvironment(name);
        if (definition == null) throw new ArgumentException("unknownConfigKey");
        int index = workingArguments.getPendingNames().indexOf(name);
        String value = workingArguments.getPendingValues().get(index);
        switch (definition.getArgType()) {
            case FLAG -> workingArguments.setFlag(name.toLowerCase(Locale.ROOT), value);
            case PARM -> workingArguments.setParameter(definition.getCli(), List.of(value));
            case DEF -> workingArguments.setDefine(definition.getCli(), List.of(value));
            case TARGET -> throw new ArgumentException("unknownConfigKey");
        }
        workingArguments.removePending(name);
    }

}
