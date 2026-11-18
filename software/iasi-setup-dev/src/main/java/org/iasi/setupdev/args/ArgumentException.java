package org.iasi.setupdev.args;

/**
 * Error de validación de argumentos identificado por una clave del catálogo.
 */
public final class ArgumentException extends IllegalArgumentException {
    /**
     * Conserva la clave del diagnóstico sin incluir datos externos.
     */
    public ArgumentException(String key) {
        super(key);
    }
}
