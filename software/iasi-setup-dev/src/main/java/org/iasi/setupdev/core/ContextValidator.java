package org.iasi.setupdev.core;

import org.iasi.setupdev.messages.InitializationMessages;

import java.io.IOException;
import java.nio.file.Path;
import java.util.Map;
import org.iasi.setupdev.args.ArgsList;
import org.iasi.setupdev.args.Arguments;
import org.iasi.setupdev.args.ArgumentException;
import org.iasi.setupdev.args.ArgumentDefinitionsValidator;
import org.iasi.setupdev.args.ArgumentValidator;
import org.iasi.setupdev.args.TargetValidator;
import org.iasi.setupdev.args.WorkingArguments;
import org.iasi.setupdev.targets.TargetDiscovery;

public final class ContextValidator {
    private final Context          ctx = Context.getInstance();
    private final ArgsList         defs;
    private final WorkingArguments workingArguments;

    public ContextValidator(ArgsList defs, WorkingArguments workingArguments) {
        this.defs             = defs;
        this.workingArguments = workingArguments;
    }

    public void validate(Arguments commandLine) {
        try {
            new ArgumentDefinitionsValidator().validateArguments(commandLine, defs);
            validateValues();
            validateTargets();
        } catch (ArgumentException exception) {
            InitializationMessages.inputError(exception.getMessage());
        } catch (IOException | SecurityException exception) {
            InitializationMessages.ioError();
        }
    }

    private void validateValues() throws IOException {
        Map<String, Object> validated = new ArgumentValidator(defs).validateArgs(workingArguments.singleValues());
        for (var entry : validated.entrySet()) {
            switch (entry.getKey()) {
                case "definitions" -> ctx.setDefinitions((Path) entry.getValue());
                case "machines" -> ctx.setMachines((Path) entry.getValue());
                case "logs" -> ctx.setLogs((Path) entry.getValue());
                case "verbose" -> ctx.setVerbose((Integer) entry.getValue());
                case "force" -> ctx.setForce((Boolean) entry.getValue());
                case "autostart" -> ctx.setAutostart((Boolean) entry.getValue());
                case "help" -> ctx.setHelp((Boolean) entry.getValue());
                case "env" -> ctx.setEnv((String) entry.getValue());
            }
        }
    }

    /**
     * Avisa de cada target ausente y acumula WARNING sin detener la ejecución.
     */
    private void validateTargets() throws IOException {
        var availableTargets = new TargetDiscovery().discover(ctx.getDefinitions());
        var selection = new TargetValidator().validateTargets(availableTargets, ctx.getTargets());
        ctx.setResolvedTargets(selection.selected());
        var missing = selection.missing();
        if (missing.isEmpty()) return;
        for (String target : missing) {
            InitializationMessages.warning("missingTarget", target, ctx.getDefinitions());
        }
    }

}
