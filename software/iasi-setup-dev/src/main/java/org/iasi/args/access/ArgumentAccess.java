package org.iasi.args.access;

import org.iasi.args.access.ArgumentAccess;
import org.iasi.args.model.*;
import org.iasi.args.loader.*;
import org.iasi.args.layer.*;
import org.iasi.args.validation.*;
import java.util.ArrayList;

/**
 * Reads indexed parameter occurrences without interpreting their data types or executing application actions.
 *
 * @author Javier G. Grandez
 * @since 0.1.0
 * @version 0.1.0
 * @history 2026-11-19 | 0.1.0 | Establish structural documentation and component responsibilities.
 */
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
