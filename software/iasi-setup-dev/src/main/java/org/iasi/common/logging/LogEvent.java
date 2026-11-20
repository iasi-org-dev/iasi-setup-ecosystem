package org.iasi.common.logging;

import java.time.ZonedDateTime;
import java.util.Objects;

/**
 * Carries immutable event metadata and sanitized text shared by all output backends.
 *
 * @author Javier G. Grandez
 * @since 0.1.0
 * @version 0.1.0
 * @history 2026-11-19 | 0.1.0 | Establish structural documentation and component responsibilities.
 */
public record LogEvent(ZonedDateTime timestamp, String code, Severity severity, String component, String message) {

    public LogEvent {
        Objects.requireNonNull(timestamp);
        Objects.requireNonNull(severity);
        Objects.requireNonNull(component);
        Objects.requireNonNull(message);
        if (code == null || !code.matches("[A-Z]{3}[0-9]{2}[0-9]{3}")) throw new IllegalArgumentException("Invalid message code");
        component = Redactor.sanitize(component);
        message = Redactor.sanitize(message);
    }
}
