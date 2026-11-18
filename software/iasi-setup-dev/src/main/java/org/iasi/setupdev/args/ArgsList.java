package org.iasi.setupdev.args;

import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.List;
import java.util.Objects;
import java.util.Locale;

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
                .filter(arg -> arg.getArgType() != ArgType.TARGET)
                .map(ARG::getEnv)
                .filter(Objects::nonNull)
                .map(name -> name.toUpperCase(Locale.ROOT))
                .distinct()
                .toList();
    }

    public ARG getByEnvironment(String name) {
        ARG flag = null;
        for (ARG arg : args.values()) {
            if (arg.getEnv() == null || !arg.getEnv().equalsIgnoreCase(name) || arg.getArgType() == ArgType.TARGET) continue;
            if (arg.getArgType() != ArgType.FLAG) return arg;
            if (flag == null) flag = arg;
        }
        return flag;
    }

    // Los flags modifican valores efectivos; config solo selecciona el fichero TOML.
    public Map<String, ARG> getValues() {
        Map<String, ARG> values = new LinkedHashMap<>();
        for (ARG arg : args.values()) {
            if (arg.getArgType() == ArgType.FLAG && arg.getEnv() != null)
                values.putIfAbsent(arg.getEnv().toLowerCase(Locale.ROOT), arg);
            if (arg.getArgType() == ArgType.DEF || arg.getArgType() == ArgType.PARM && arg.getEnv() != null)
                values.put(arg.getCli(), arg);
        }
        return Collections.unmodifiableMap(values);
    }
}
