package org.iasi.setupdev.args.model;

import org.iasi.setupdev.args.loader.*;
import org.iasi.setupdev.args.layer.*;
import org.iasi.setupdev.args.validation.*;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import lombok.Getter;

/**
 * Accumulates textual configuration layers and keeps unclassified environment values separate until reconciliation.
 *
 * @author Javier G. Grandez
 * @since 0.1.0
 * @version 0.1.0
 * @history 2026-11-19 | 0.1.0 | Establish structural documentation and component responsibilities.
 */
@Getter
public final class WorkingArguments extends Arguments {
    private final ArrayList<String> flagValues    = new ArrayList<>();
    private final ArrayList<String> pendingNames  = new ArrayList<>();
    private final ArrayList<String> pendingValues = new ArrayList<>();

    /**
     * Updates an already classified value or defers a new environment name without guessing whether it is a flag, parameter or definition.
     */
    public void setArgument(String name, String value) {
        var singleValue = new ArrayList<>(List.of(value));
        if (updateExisting(getParameters(), getParameterValues(), name, singleValue)) return;
        if (updateExisting(getDefines(), getDefineValues(), name, singleValue)) return;
        if (updateExisting(getFlags(), flagValues, name, value)) return;
        setPending(name, value);
    }

    public void setParameter(String name, List<String> values) {
        remove(getFlags(), flagValues, name);
        remove(getDefines(), getDefineValues(), name);
        setValues(getParameters(), getParameterValues(), name, values);
    }

    public void setDefine(String name, List<String> values) {
        remove(getFlags(), flagValues, name);
        remove(getParameters(), getParameterValues(), name);
        setValues(getDefines(), getDefineValues(), name, values);
    }

    public void setFlag(String name, String value) {
        remove(getParameters(), getParameterValues(), name);
        remove(getDefines(), getDefineValues(), name);
        int index = indexOf(getFlags(), name);
        if (index >= 0) flagValues.set(index, value);
        else {
            getFlags().add(name);
            flagValues.add(value);
        }
    }

    public void removePending(String name) {
        if (name != null) remove(pendingNames, pendingValues, name);
    }

    public List<String> getArgument(String name) {
        int index = indexOf(getParameters(), name);
        if (index >= 0) return List.copyOf(getParameterValues().get(index));
        index = indexOf(getDefines(), name);
        if (index >= 0) return List.copyOf(getDefineValues().get(index));
        index = indexOf(getFlags(), name);
        if (index >= 0) return List.of(flagValues.get(index));
        return null;
    }

    public Map<String, String> singleValues() {
        Map<String, String> values = new HashMap<>();
        addValues(values, getParameters(), getParameterValues());
        addValues(values, getDefines(), getDefineValues());
        for (int index = 0; index < getFlags().size(); index++)
            values.put(getFlags().get(index), flagValues.get(index));
        return values;
    }

    private void setPending(String name, String value) {
        int index = indexOf(pendingNames, name);
        if (index >= 0) pendingValues.set(index, value);
        else {
            pendingNames.add(name.toUpperCase(Locale.ROOT));
            pendingValues.add(value);
        }
    }

    private void setValues(ArrayList<String> names, ArrayList<ArrayList<String>> values, String name, List<String> value) {
        int index = indexOf(names, name);
        if (index >= 0) values.set(index, new ArrayList<>(value));
        else {
            names.add(name);
            values.add(new ArrayList<>(value));
        }
    }

    private int indexOf(List<String> names, String name) {
        for (int index = 0; index < names.size(); index++) {
            if (names.get(index).equalsIgnoreCase(name)) return index;
        }
        return -1;
    }

    private <T> boolean updateExisting(List<String> names, List<T> values, String name, T value) {
        int index = indexOf(names, name);
        if (index < 0) return false;
        values.set(index, value);
        return true;
    }

    private void remove(List<String> names, List<?> values, String name) {
        int index = indexOf(names, name);
        if (index < 0) return;
        names.remove(index);
        values.remove(index);
    }

    private void addValues(Map<String, String> result, List<String> names, List<? extends List<String>> values) {
        for (int index = 0; index < names.size(); index++) {
            if (values.get(index).size() != 1) throw new ArgumentException("repeatedArgument");
            result.put(names.get(index), values.get(index).getFirst());
        }
    }
}
