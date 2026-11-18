package org.iasi.setupdev.core;

import java.io.PrintStream;
import java.nio.file.Path;
import java.util.List;
import org.iasi.base.RC;

/**
 * Contexto único y mutable de una ejecución monohilo de la aplicación.
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

    /**
     * Crea el contexto con los valores por defecto hardcoded.
     */
    private Context() {
    }

    /**
     * Devuelve el prefijo del entorno; null indica que no está habilitado.
     */
    public String getEnv() {
        return env;
    }

    /**
     * Actualiza el prefijo utilizado para consultar variables de entorno.
     */
    public void setEnv(String env) {
        this.env = env;
    }

    /**
     * Crea el singleton en la primera llamada y devuelve siempre esa instancia.
     */
    public static Context getInstance() {
        if (instance == null) instance = new Context();
        return instance;
    }

    /**
     * Devuelve el directorio donde se buscan las definiciones de máquinas.
     */
    public Path getDefinitions() {
        return definitions;
    }

    /**
     * Actualiza el directorio donde se buscan las definiciones de máquinas.
     */
    public void setDefinitions(Path definitions) {
        this.definitions = definitions;
    }

    /**
     * Conserva una sola vez los targets originales, sin resolverlos ni filtrarlos.
     */
    public void initializeTargets(List<String> targets) {
        if (targetsInitialized) throw new IllegalStateException("Original targets are already initialized");
        this.targets = List.copyOf(targets);
        targetsInitialized = true;
    }

    /**
     * Devuelve los targets originales en orden e inmutables; vacío significa
     * todas las definiciones del directorio efectivo.
     */
    public List<String> getTargets() {
        return targets;
    }

    /**
     * Devuelve las coincidencias actuales, separadas de los patrones originales.
     */
    public List<Path> getResolvedTargets() {
        return resolvedTargets;
    }

    /**
     * Actualiza la selección de trabajo sin alterar los targets originales.
     */
    public void setResolvedTargets(List<Path> targets) {
        resolvedTargets = List.copyOf(targets);
    }

    /**
     * Devuelve el directorio de máquinas.
     */
    public Path getMachines() {
        return machines;
    }

    /**
     * Actualiza el directorio de máquinas.
     */
    public void setMachines(Path machines) {
        this.machines = machines;
    }

    /**
     * Devuelve el directorio de logs.
     */
    public Path getLogs() {
        return logs;
    }

    /**
     * Actualiza el directorio de logs.
     */
    public void setLogs(Path logs) {
        this.logs = logs;
    }

    /**
     * Devuelve el nivel de verbosidad.
     */
    public int getVerbose() {
        return verbose;
    }

    /**
     * Actualiza el nivel de verbosidad.
     */
    public void setVerbose(int verbose) {
        this.verbose = verbose;
    }

    /**
     * Indica si la ejecución está forzada.
     */
    public boolean isForce() {
        return force;
    }

    /**
     * Actualiza la opción de ejecución forzada.
     */
    public void setForce(boolean force) {
        this.force = force;
    }

    /**
     * Indica si las máquinas deben arrancarse después de crearlas.
     */
    public boolean isAutostart() {
        return autostart;
    }

    /**
     * Actualiza la opción de arranque después de crear una máquina.
     */
    public void setAutostart(boolean autostart) {
        this.autostart = autostart;
    }

    /**
     * Indica si la ejecución solicita ayuda.
     */
    public boolean isHelp() {
        return help;
    }

    /**
     * Conserva la solicitud de ayuda de la ejecución.
     */
    public void setHelp(boolean help) {
        this.help = help;
    }

    /**
     * Acumula los indicadores del código de retorno.
     */
    public void setRC(int value) {
        rc |= value;
    }

    /**
     * Devuelve el código de retorno acumulado.
     */
    public int getRC() {
        return rc;
    }

    /**
     * Devuelve la salida de errores del proceso.
     */
    public PrintStream err() {
        return err;
    }

    /**
     * Devuelve la salida normal conservada al crear el contexto.
     */
    public PrintStream out() {
        return out;
    }
}
