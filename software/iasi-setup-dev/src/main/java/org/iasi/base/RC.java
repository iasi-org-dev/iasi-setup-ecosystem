package org.iasi.base;

/**
 * Defines composable IASI return-code bits without deciding execution flow.
 *
 * @author Javier G. Grandez
 * @since 0.1.0
 * @version 0.1.0
 * @history 2026-11-19 | 0.1.0 | Establish structural documentation and component responsibilities.
 */
public final class RC {
    public static final int OK = 0x00;
    public static final int NOTHING_TO_DO = 0x01;
    public static final int INFO = 0x02;
    public static final int WARNING = 0x04;
    public static final int ATTENTION = 0x08;
    public static final int ERROR = 0x10;
    public static final int SEVERE = 0x20;
    public static final int FATAL = 0x40;

    private RC() {
    }

    public static boolean isValid(int value) {
        return value >= OK && value <= 0x7F;
    }

    public static boolean isError(int value) {
        return (value & (ERROR | SEVERE | FATAL)) != 0;
    }
}
