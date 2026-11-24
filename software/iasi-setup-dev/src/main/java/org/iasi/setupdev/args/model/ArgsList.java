package org.iasi.setupdev.args.model;

import org.iasi.setupdev.args.loader.*;
import org.iasi.setupdev.args.layer.*;
import org.iasi.setupdev.args.validation.*;
import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.List;
import java.util.Objects;
import java.util.Locale;

/**
 * Indexes supported argument declarations and exposes their environment bindings and effective-value schema.
 *
 * @author Javier G. Grandez
 * @since 0.1.0
 * @version 0.1.0
 * @history 2026-11-19 | 0.1.0 | Establish structural documentation and component responsibilities.
 */
public final class ArgsList {
    private final Map<String, ARG> args = new LinkedHashMap<>();

    public ArgsList add(ARG arg) {
        if (args.putIfAbsent(arg.getCli(), arg) != null) throw new IllegalArgumentException("Duplicate argument: " + arg.getCli());
        return this;
    }

    public ARG get(String cli) {
        return args.get(cli);
    }

    public Map<String, ARG> getArgs() {
        return Collections.unmodifiableMap(args);
    }

    public List<String> getEnvironmentNames() {
        return args.values().stream()
                .map(this::environmentName)
                .filter(Objects::nonNull)
                .distinct()
                .toList();
    }

    public ARG getByEnvironment(String name) {
        ARG flag = null;
        for (ARG arg : args.values()) {
            String environmentName = environmentName(arg);
            if (environmentName == null || !environmentName.equalsIgnoreCase(name)) continue;
            if (arg.getArgType() != ArgType.FLAG) return arg;
            if (flag == null) flag = arg;
        }
        return flag;
    }

    private String environmentName(ARG arg) {
        if (arg.getArgType() == ArgType.TARGET) return null;
        if (arg.getArgType() == ArgType.FLAG && arg.getEnv() == null) return null;
        String name = arg.getEnv() == null ? arg.getCli() : arg.getEnv();
        return name.replace('-', '_').toUpperCase(Locale.ROOT);
    }

    public Map<String, ARG> getValues() {
        Map<String, ARG> values = new LinkedHashMap<>();
        for (ARG arg : args.values()) {
            if (arg.getArgType() == ArgType.TARGET) continue;
            String name = arg.getArgType() == ArgType.FLAG && arg.getEnv() != null
                    ? arg.getEnv().toLowerCase(Locale.ROOT) : arg.getCli();
            values.put(name, arg);
        }
        return Collections.unmodifiableMap(values);
    }
}
