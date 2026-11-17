package org.iasisetupdev.core;

import java.time.Instant;
import java.util.Objects;
import java.util.UUID;
import org.iasi.base.RC;

/**
 * Contexto único por proceso: configuración e identidad estables y RC mutable
 * protegido. Sin reset.
 */
public final class Context {
    private static Context instance;
    private final ExecutionConfiguration configuration;
    private final UUID executionId;
    private final Instant startedAt;
    private int rc = RC.OK;

    /**
     * Construye todos los valores estables antes de publicar la instancia bajo el
     * monitor de clase.
     */
    private Context(ExecutionConfiguration configuration) {
        this.configuration = Objects.requireNonNull(configuration);
        executionId = UUID.randomUUID();
        startedAt = Instant.now();
    }

    /**
     * Publica una sola configuración validada; una segunda inicialización se
     * rechaza sin sustituir el contexto.
     */
    public static synchronized Context initialize(ExecutionConfiguration configuration) {
        if (instance != null) throw new IllegalStateException("Context is already initialized");
        instance = new Context(configuration);
        return instance;
    }

    /**
     * Obtiene la instancia completamente inicializada; el bootstrap no expone un
     * contexto provisional.
     */
    public static synchronized Context getInstance() {
        if (instance == null) throw new IllegalStateException("Context is not initialized");
        return instance;
    }

    /**
     * Configuración efectiva de solo lectura, estable durante toda la ejecución.
     */
    public ExecutionConfiguration configuration() {
        return configuration;
    }

    /**
     * Identidad única e inmutable de la ejecución, compartida por todos los
     * consumidores.
     */
    public UUID executionId() {
        return executionId;
    }

    /**
     * Instante fijado al construir el contexto; no cambia con las consultas o
     * actualizaciones de RC.
     */
    public Instant startedAt() {
        return startedAt;
    }

    /**
     * Acumula una máscara IASI válida mediante OR atómico; no valida, lanza ni
     * decide el flujo de ejecución.
     */
    public synchronized void setRC(int value) {
        rc |= value;
    }

    /**
     * Lee el acumulado con la misma protección que sus escrituras para garantizar
     * visibilidad.
     */
    public synchronized int getRC() {
        return rc;
    }
}
