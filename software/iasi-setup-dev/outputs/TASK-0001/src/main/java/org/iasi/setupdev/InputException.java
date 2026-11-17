package org.iasi.setupdev;

final class InputException extends IllegalArgumentException {
    /**
     * Transporta una clave de diagnóstico controlada; nunca incluye el argumento o
     * archivo externo sin sanear.
     */
    InputException(String key) {
        super(key);
    }
}
