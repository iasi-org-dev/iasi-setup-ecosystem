package org.iasi.common.logging;

public enum Verbosity {
    NORMAL, VERBOSE, VERY_VERBOSE, SILENT;

    /**
     * Decide visibilidad en consola sin alterar el evento ni el filtro
     * independiente de persistencia.
     */
    public boolean includes(Severity severity) {
        if (severity == Severity.ERROR) return true;
        if (this == SILENT) return false;
        if (severity == Severity.TRACE) return this == VERY_VERBOSE;
        if (severity == Severity.DEBUG) return this == VERBOSE || this == VERY_VERBOSE;
        return true;
    }
}
