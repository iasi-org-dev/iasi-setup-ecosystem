package org.iasi.setupdev.args.model;

import org.iasi.setupdev.args.access.ArgumentAccess;
import org.iasi.setupdev.args.loader.*;
import org.iasi.setupdev.args.layer.*;
import org.iasi.setupdev.args.validation.*;
import java.util.ArrayList;
import lombok.Getter;
import lombok.Setter;

/**
 * Stores syntax-only command-line data in indexed name/value lists, preserving occurrence order.
 *
 * @author Javier G. Grandez
 * @since 0.1.0
 * @version 0.1.0
 * @history 2026-11-19 | 0.1.0 | Establish structural documentation and component responsibilities.
 */
@Getter
@Setter
public class Arguments {
    private ArrayList<String>               flags           = new ArrayList<>();
    private ArrayList<String>               parameters      = new ArrayList<>();
    private ArrayList<ArrayList<String>>    parameterValues = new ArrayList<>();
    private ArrayList<String>               defines         = new ArrayList<>();
    private ArrayList<ArrayList<String>>    defineValues    = new ArrayList<>();
    private ArrayList<String>               targets         = new ArrayList<>();

    public Arguments() {
    }

    public int count(String name) {
        return ArgumentAccess.values(this, name).size();
    }
}
