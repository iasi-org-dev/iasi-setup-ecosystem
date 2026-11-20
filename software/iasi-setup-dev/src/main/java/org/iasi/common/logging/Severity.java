package org.iasi.common.logging;

/**
 * Associates message severity with console presentation colors.
 *
 * @author Javier G. Grandez
 * @since 0.1.0
 * @version 0.1.0
 * @history 2026-11-19 | 0.1.0 | Establish structural documentation and component responsibilities.
 */
public enum Severity {
    MESSAGE(""), INFO("36"), SUCCESS("32"), WARNING("33"), ERROR("31"), DEBUG("90"), TRACE("90");

    private final String color;

    Severity(String color) {
        this.color = color;
    }

    String color() {
        return color;
    }
}
