package org.iasi.setupdev.core;

import org.iasi.setupdev.messages.InitializationMessages;

import java.io.IOException;
import java.nio.file.Path;
import java.util.Map;
import org.iasi.args.model.ArgsList;
import org.iasi.args.model.Arguments;
import org.iasi.args.validation.ArgumentException;
import org.iasi.args.validation.ArgumentDefinitionsValidator;
import org.iasi.args.validation.ArgumentValidator;
import org.iasi.setupdev.targets.TargetValidator;
import org.iasi.args.model.WorkingArguments;
import org.iasi.setupdev.targets.TargetDiscovery;

/**
 * Publishes validated application values and resolves targets, aborting initialization on known failures.
 *
 * @author Javier G. Grandez
 * @since 0.1.0
 * @version 0.1.0
 * @history 2026-11-19 | 0.1.0 | Establish structural documentation and component responsibilities.
 */
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
        Map<String, Object> validated = new ArgumentValidator(defs).validateArgs(workingArguments);
        updateContext(validated);
    }

    private void updateContext(Map<String, Object> validated) {
        for (var entry : validated.entrySet()) {
            switch (entry.getKey()) {
                case "id-host" -> ctx.setIdHost((String) entry.getValue());
                case "id-machines" -> ctx.setIdMachines((String) entry.getValue());
                case "definitions" -> ctx.setDefinitions((Path) entry.getValue());
                case "machines" -> ctx.setMachines((Path) entry.getValue());
                case "logs" -> ctx.setLogs((Path) entry.getValue());
                case "verbose" -> ctx.setVerbose((Integer) entry.getValue());
                case "force" -> ctx.setForce((Boolean) entry.getValue());
                case "recreate" -> ctx.setRecreate((Boolean) entry.getValue());
                case "autostart" -> ctx.setAutostart((Boolean) entry.getValue());
                case "help" -> ctx.setHelp((Boolean) entry.getValue());
                case "env" -> ctx.setEnv((String) entry.getValue());
            }
        }
    }

    private void validateTargets() throws IOException {
        var availableTargets = new TargetDiscovery().discover(ctx.getDefinitions(), ctx.getIdMachines());
        var selection = new TargetValidator().validateTargets(availableTargets, ctx.getTargets());
        ctx.setResolvedTargets(selection.selected());
        var missing = selection.missing();
        if (missing.isEmpty()) return;
        for (String target : missing) {
            InitializationMessages.warning("missingTarget", target, ctx.getDefinitions());
        }
    }

}
