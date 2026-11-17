package org.iasi.common.operation;

import java.util.Objects;
import java.util.Optional;
import org.iasi.base.RC;

/**
 * Resultado de una operación común: datos opcionales y RC explícito, sin
 * inferirlo de sus mensajes.
 */
public record OperationResult<T>(Optional<T> value, int status) {
    /**
     * Exige contenedor y RC definidos, permitiendo resultados parciales sin alterar
     * la política de continuación.
     */
    public OperationResult {
        Objects.requireNonNull(value);
        if (!RC.isValid(status)) throw new IllegalArgumentException("Invalid IASI RC mask");
    }

    /**
     * Resultado normal sin circunstancias adicionales; imprimir sus datos no activa
     * Info.
     */
    public static <T> OperationResult<T> completed(T value) {
        return withValue(value, RC.OK);
    }

    /**
     * Transporta datos y circunstancias decididas por la operación, no por el
     * adaptador de consola.
     */
    public static <T> OperationResult<T> withValue(T value, int status) {
        return new OperationResult<>(Optional.of(value), status);
    }

    /**
     * Representa una operación sin trabajo aplicable, sin crear un valor de
     * resultado ficticio.
     */
    public static <T> OperationResult<T> nothingToDo() {
        return new OperationResult<>(Optional.empty(), RC.NOTHING_TO_DO);
    }
}
