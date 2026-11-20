package org.iasi.setupdev.core;

import java.io.PrintStream;
import java.nio.file.Path;
import java.util.List;
import org.iasi.base.RC;

/**
 * Holds one single-threaded execution state, borrowed console streams and immutable original target selections.
 *
 * @author Javier G. Grandez
 * @since 0.1.0
 * @version 0.1.0
 * @history 2026-11-19 | 0.1.0 | Establish structural documentation and component responsibilities.
 */
public final class Context {
    private static Context instance;
    private final PrintStream out = System.out;
    private final PrintStream err = System.err;
    private Path definitions = Path.of(".");
    private List<String> targets = List.of();
    private List<Path> resolvedTargets = List.of();
    private boolean targetsInitialized;
    private Path machines = Path.of(".");
    private Path logs = Path.of(".");
    private int verbose = 1;
    private String env;
    private boolean force = false;
    private boolean autostart = false;
    private boolean help = false;
    private int rc = RC.OK;

    private Context() {
    }

    public String getEnv() {
        return env;
    }

    public void setEnv(String env) {
        this.env = env;
    }

    public static Context getInstance() {
        if (instance == null) instance = new Context();
        return instance;
    }

    public Path getDefinitions() {
        return definitions;
    }

    public void setDefinitions(Path definitions) {
        this.definitions = definitions;
    }

    /**
     * Copies the original target patterns once; later selections must use the separate resolved-target list.
     * @throws IllegalStateException if the originals were already initialized
     */
    public void initializeTargets(List<String> targets) {
        if (targetsInitialized) throw new IllegalStateException("Original targets are already initialized");
        this.targets = List.copyOf(targets);
        targetsInitialized = true;
    }

    /**
     * Returns immutable original patterns in CLI order. An empty list requests all discovered targets.
     */
    public List<String> getTargets() {
        return targets;
    }

    public List<Path> getResolvedTargets() {
        return resolvedTargets;
    }

    public void setResolvedTargets(List<Path> targets) {
        resolvedTargets = List.copyOf(targets);
    }

    public Path getMachines() {
        return machines;
    }

    public void setMachines(Path machines) {
        this.machines = machines;
    }

    public Path getLogs() {
        return logs;
    }

    public void setLogs(Path logs) {
        this.logs = logs;
    }

    public int getVerbose() {
        return verbose;
    }

    public void setVerbose(int verbose) {
        this.verbose = verbose;
    }

    public boolean isForce() {
        return force;
    }

    public void setForce(boolean force) {
        this.force = force;
    }

    public boolean isAutostart() {
        return autostart;
    }

    public void setAutostart(boolean autostart) {
        this.autostart = autostart;
    }

    public boolean isHelp() {
        return help;
    }

    public void setHelp(boolean help) {
        this.help = help;
    }

    /**
     * Accumulates status bits with OR only; it neither validates the mask nor changes execution flow.
     */
    public void setRC(int value) {
        rc |= value;
    }

    public int getRC() {
        return rc;
    }

    public PrintStream err() {
        return err;
    }

    public PrintStream out() {
        return out;
    }
}
