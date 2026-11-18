package org.iasi.setupdev.args;

import java.util.List;
import java.util.Locale;
import org.iasi.setupdev.core.Context;
import org.iasi.setupdev.messages.InitializationMessages;

public final class EnvironmentArguments {
    private final ArgsList definitions;

    public EnvironmentArguments(ArgsList definitions) {
        this.definitions = definitions;
    }

    public void apply(Arguments commandLine, WorkingArguments working) {
        try {
            switch (commandLine.count("env")) {
                case 0: applyInheritedPrefix(working); return;
                case 1: applyExplicitPrefix(commandLine, working); return;
                default: InitializationMessages.inputError("tooManyEnvironments");
            }
        } catch (ArgumentException exception) {
            InitializationMessages.inputError(exception.getMessage());
        } catch (SecurityException exception) {
            InitializationMessages.ioError();
        }
    }

    private void applyInheritedPrefix(WorkingArguments working) {
        String prefix = ArgumentAccess.singleValue(working, "env");
        if (prefix == null) prefix = Context.getInstance().getEnv();
        if (prefix != null) applyVariables(prefix, working);
    }

    private void applyExplicitPrefix(Arguments commandLine, WorkingArguments working) {
        String prefix = ArgumentAccess.singleValue(commandLine, "env");
        working.setParameter("env", List.of(prefix));
        applyVariables(prefix, working);
    }

    private void applyVariables(String prefix, WorkingArguments working) {
        for (String name : definitions.getEnvironmentNames())
            applyVariable(prefix, name, working);
    }

    private void applyVariable(String prefix, String name, WorkingArguments working) {
        String variable = (prefix + "_" + name).toUpperCase(Locale.ROOT);
        String value = System.getenv(variable);
        if (value != null) working.setArgument(name, value);
    }
}
