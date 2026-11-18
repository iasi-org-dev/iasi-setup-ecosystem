package org.iasi.setupdev.args;

import java.util.ArrayList;
import lombok.Getter;
import lombok.Setter;

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
