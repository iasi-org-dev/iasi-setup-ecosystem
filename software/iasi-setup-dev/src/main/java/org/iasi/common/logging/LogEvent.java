package org.iasi.common.logging;

import java.time.ZonedDateTime;
import java.util.Objects;

/**
 * Evento inmutable ya localizado y saneado, compartido por todos los destinos.
 */
public record LogEvent(ZonedDateTime timestamp, String code, Severity severity, String component, String message) {
    /**
     * Valida identidad y metadatos y sanea el texto incluso cuando se construye
     * fuera de la fachada.
     */
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
