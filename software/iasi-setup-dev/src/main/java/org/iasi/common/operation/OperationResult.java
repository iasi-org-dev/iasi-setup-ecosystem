package org.iasi.common.operation;

import java.util.Objects;
import java.util.Optional;
import org.iasi.base.RC;

/**
 * Combines optional operation data with an explicit return-code mask, without inferring status from messages.
 *
 * @author Javier G. Grandez
 * @since 0.1.0
 * @version 0.1.0
 * @history 2026-11-19 | 0.1.0 | Establish structural documentation and component responsibilities.
 */
public record OperationResult<T>(Optional<T> value, int status) {

    public OperationResult {
        Objects.requireNonNull(value);
        if (!RC.isValid(status)) throw new IllegalArgumentException("Invalid IASI RC mask");
    }

    public static <T> OperationResult<T> completed(T value) {
        return withValue(value, RC.OK);
    }

    public static <T> OperationResult<T> withValue(T value, int status) {
        return new OperationResult<>(Optional.of(value), status);
    }

    public static <T> OperationResult<T> nothingToDo() {
        return new OperationResult<>(Optional.empty(), RC.NOTHING_TO_DO);
    }
}
