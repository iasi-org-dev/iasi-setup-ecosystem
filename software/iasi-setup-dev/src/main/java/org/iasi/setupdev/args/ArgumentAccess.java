package org.iasi.setupdev.args;

import java.util.ArrayList;

public final class ArgumentAccess {
    private ArgumentAccess() {
    }

    public static String singleValue(Arguments arguments, String name) {
        int index = arguments.getParameters().indexOf(name);
        if (index < 0) return null;
        if (arguments.getParameters().lastIndexOf(name) != index) throw new ArgumentException("repeatedArgument");
        var values = arguments.getParameterValues().get(index);
        if (values.size() != 1) throw new ArgumentException("repeatedArgument");
        return values.getFirst();
    }

    public static ArrayList<String> values(Arguments arguments, String name) {
        ArrayList<String> values = new ArrayList<>();
        for (int index = 0; index < arguments.getParameters().size(); index++) {
            if (arguments.getParameters().get(index).equals(name)) values.addAll(arguments.getParameterValues().get(index));
        }
        return values;
    }

}
