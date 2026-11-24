package org.iasi.setupdev.core;

import org.iasi.setupdev.messages.InitializationMessages;

import org.iasi.setupdev.args.model.ARG;
import org.iasi.setupdev.args.model.ArgClass;
import org.iasi.setupdev.args.model.ArgType;
import org.iasi.setupdev.args.model.ArgsList;
import org.iasi.setupdev.args.model.Arguments;
import org.iasi.setupdev.args.layer.CommandLineArguments;
import org.iasi.setupdev.args.loader.CommandLineLoader;
import org.iasi.setupdev.args.layer.EnvironmentArguments;
import org.iasi.setupdev.args.model.WorkingArguments;
import org.iasi.setupdev.configuration.ExternalConfiguration;
import org.iasi.setupdev.configuration.InternalConfiguration;
import org.iasi.setupdev.console.Help;

/**
 * Coordinates configuration layers in precedence order and returns the validated singleton context.
 *
 * @author Javier G. Grandez
 * @since 0.1.0
 * @version 0.1.0
 * @history 2026-11-19 | 0.1.0 | Establish structural documentation and component responsibilities.
 * @history 2026-11-20 | 0.1.0 | Apply bundled TOML defaults before external configuration layers.
 * @history 2026-11-20 | 0.1.0 | Require effective administrator privileges before processing inputs or configuration.
 * @history 2026-11-20 | 0.1.0 | Move OS and privilege prerequisites to the process entry point.
 */
public final class Initializer {
    private final Context          ctx              = Context.getInstance();
    private final WorkingArguments workingArguments = new WorkingArguments();
    private ArgsList definitions;

    public Context initialize(String[] args) {
        try {
            definitions = createArgumentDefinitions();
            Arguments commandLine = new CommandLineLoader(args);
            ctx.initializeTargets(commandLine.getTargets());
            if (showHelp(commandLine)) return ctx;
            applyInternalConfiguration();
            applyExternalConfiguration(commandLine);
            applyEnvironment(commandLine);
            applyArguments(commandLine);
            validateArgs(commandLine);
        } catch (Exception exception) {
            InitializationMessages.unexpectedFailure();
        }
        return ctx;
    }

    private void applyInternalConfiguration() {
        new InternalConfiguration().apply(workingArguments);
    }

    private boolean showHelp(Arguments commandLine) {
        if (!commandLine.getFlags().contains("h")) return false;
        ctx.setHelp(true);
        new Help().show(ctx.out());
        return true;
    }

    private void applyExternalConfiguration(Arguments commandLine) {
        new ExternalConfiguration().apply(commandLine, workingArguments);
    }

    private void applyEnvironment(Arguments commandLine) {
        new EnvironmentArguments(definitions).apply(commandLine, workingArguments);
    }

    private void applyArguments(Arguments commandLine) {
        new CommandLineArguments(definitions, workingArguments).apply(commandLine);
    }

    private void validateArgs(Arguments commandLine) {
        new ContextValidator(definitions, workingArguments).validate(commandLine);
    }

    public ArgsList createArgumentDefinitions() {
        return new ArgsList()
            .add(new ARG("h",            null,          ArgType.FLAG,   ArgClass.BOOLEAN))
            .add(new ARG("f",            null,          ArgType.FLAG,   ArgClass.BOOLEAN))
            .add(new ARG("r",            null,          ArgType.FLAG,   ArgClass.BOOLEAN))
            .add(new ARG("a",            null,          ArgType.FLAG,   ArgClass.BOOLEAN))
            .add(new ARG("v",            "VERBOSE",     ArgType.FLAG,   ArgClass.NATURAL))
            .add(new ARG("V",            "VERBOSE",     ArgType.FLAG,   ArgClass.NATURAL))
            .add(new ARG("s",            "VERBOSE",     ArgType.FLAG,   ArgClass.INTEGER))
            .add(new ARG("config",       null,          ArgType.PARM,   ArgClass.FILE))
            .add(new ARG("env",          "ENV",         ArgType.PARM,   ArgClass.STRING))
            .add(new ARG("id-host",      "ID_HOST",     ArgType.PARM,   ArgClass.STRING))
            .add(new ARG("id-machines",   "ID_MACHINES", ArgType.PARM,   ArgClass.STRING))
            .add(new ARG("definitions",  "DEFINITIONS", ArgType.PARM,   ArgClass.DIRECTORY))
            .add(new ARG("machines",     "MACHINES",    ArgType.PARM,   ArgClass.DIRECTORY))
            .add(new ARG("logs",         "LOGS",        ArgType.PARM,   ArgClass.DIRECTORY))
            .add(new ARG("force",        null,          ArgType.FLAG,   ArgClass.BOOLEAN))
            .add(new ARG("autostart",    null,          ArgType.FLAG,   ArgClass.BOOLEAN))
            .add(new ARG("help",         null,          ArgType.FLAG,   ArgClass.BOOLEAN));
    }
}
