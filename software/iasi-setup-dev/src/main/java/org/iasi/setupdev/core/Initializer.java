package org.iasi.setupdev.core;

import org.iasi.setupdev.messages.InitializationMessages;

import org.iasi.setupdev.args.ARG;
import org.iasi.setupdev.args.ArgClass;
import org.iasi.setupdev.args.ArgType;
import org.iasi.setupdev.args.ArgsList;
import org.iasi.setupdev.args.Arguments;
import org.iasi.setupdev.args.CommandLineArguments;
import org.iasi.setupdev.args.CommandLineLoader;
import org.iasi.setupdev.args.EnvironmentArguments;
import org.iasi.setupdev.args.WorkingArguments;
import org.iasi.setupdev.configuration.ExternalConfiguration;

public final class Initializer {
    private final Context          ctx              = Context.getInstance();
    private final WorkingArguments workingArguments = new WorkingArguments();

    public Context initialize(String[] args) {
        try {
            ArgsList definitions = createArgumentDefinitions();
            Arguments commandLine = new CommandLineLoader(args);
            ctx.initializeTargets(commandLine.getTargets());
            applyInternalConfiguration();
            new ExternalConfiguration().apply(commandLine, workingArguments);
            new EnvironmentArguments(definitions).apply(commandLine, workingArguments);
            new CommandLineArguments(definitions, workingArguments).apply(commandLine);
            new ContextValidator(definitions, workingArguments).validate(commandLine);
        } catch (Exception exception) {
            InitializationMessages.unexpectedFailure();
        }
        return ctx;
    }

    private void applyInternalConfiguration() {
        // Esta aplicación no incluye configuración interna en resources.
    }

    public ArgsList createArgumentDefinitions() {
        return new ArgsList()
            .add(new ARG("h",            null,          ArgType.FLAG,   ArgClass.BOOLEAN))
            .add(new ARG("f",            null,          ArgType.FLAG,   ArgClass.BOOLEAN))
            .add(new ARG("a",            null,          ArgType.FLAG,   ArgClass.BOOLEAN))
            .add(new ARG("v",            "VERBOSE",     ArgType.FLAG,   ArgClass.NATURAL))
            .add(new ARG("V",            "VERBOSE",     ArgType.FLAG,   ArgClass.NATURAL))
            .add(new ARG("s",            "VERBOSE",     ArgType.FLAG,   ArgClass.INTEGER))
            .add(new ARG("config",       null,          ArgType.PARM,   ArgClass.FILE,      false, false, true))
            .add(new ARG("env",          "ENV",         ArgType.PARM,   ArgClass.STRING))
            .add(new ARG("definitions",  "DEFINITIONS", ArgType.PARM,   ArgClass.DIRECTORY))
            .add(new ARG("machines",     "MACHINES",    ArgType.PARM,   ArgClass.DIRECTORY))
            .add(new ARG("logs",         "LOGS",        ArgType.PARM,   ArgClass.DIRECTORY))
            .add(new ARG("verbose",      "VERBOSE",     ArgType.DEF,    ArgClass.INTEGER))
            .add(new ARG("force",        null,          ArgType.DEF,    ArgClass.BOOLEAN))
            .add(new ARG("autostart",    null,          ArgType.DEF,    ArgClass.BOOLEAN))
            .add(new ARG("help",         null,          ArgType.DEF,    ArgClass.BOOLEAN))
            .add(new ARG("targets",      null,          ArgType.TARGET, ArgClass.STRING,    false, true,  false));
    }
}
