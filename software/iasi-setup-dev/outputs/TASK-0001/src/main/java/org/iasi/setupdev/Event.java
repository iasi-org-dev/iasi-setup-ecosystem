package org.iasi.setupdev;

import org.iasi.common.logging.MessageDefinition;
import org.iasi.common.logging.Severity;

enum Event implements MessageDefinition {
    START("SYS01001", Severity.INFO, "start"), PATHS("SYS01002", Severity.DEBUG, "paths"), PLATFORM("SYS01003", Severity.INFO, "platform"), RUNTIME("SYS01004",
            Severity.TRACE, "runtime"), VERIFIED("SYS01005", Severity.SUCCESS, "verified"), UNKNOWN_HOST("SYS01006", Severity.ERROR, "unknownHost"), FINISH(
                    "SYS01007", Severity.INFO, "finish"), WARNING("SYS01008", Severity.WARNING, "warning"), INPUT_ERROR("CLI01001", Severity.ERROR,
                            "inputError"), UNAVAILABLE("CLI01002", Severity.ERROR, "unavailable"), IO_ERROR("SYS01009", Severity.ERROR, "ioError");

    private final String code;
    private final Severity severity;
    private final String key;

    /**
     * Fija código, severidad y plantilla del evento de esta aplicación sin
     * vincularlo a ningún backend.
     */
    Event(String code, Severity severity, String key) {
        this.code = code;
        this.severity = severity;
        this.key = key;
    }

    /**
     * Identificador estable conservado entre traducciones y adaptadores de logging.
     */
    public String code() {
        return code;
    }

    /**
     * Severidad funcional declarada por la aplicación, independiente del prefijo
     * del código.
     */
    public Severity severity() {
        return severity;
    }

    /** Clave de traducción del catálogo propio del launcher. */
    public String key() {
        return key;
    }
}
