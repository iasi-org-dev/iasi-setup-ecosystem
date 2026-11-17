package org.iasi.common.logging;

public enum Severity {
    INFO(""), SUCCESS("32"), WARNING("33"), ERROR("31"), DEBUG("90"), TRACE("90");

    private final String color;

    /**
     * Asocia un estilo ANSI de consola; el color no determina la identidad ni la
     * severidad del evento.
     */
    Severity(String color) {
        this.color = color;
    }

    /**
     * Código ANSI interno para el adaptador de consola; vacío conserva el color
     * predeterminado.
     */
    String color() {
        return color;
    }
}
