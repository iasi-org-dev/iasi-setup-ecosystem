package org.iasi.base;

/**
 * Constantes enteras de COR-MSG-RC-001; las combinaciones se forman con OR, sin
 * nombres adicionales.
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

    /**
     * Clase de constantes; no hay instancias, ordinales ni conversiones desde enum.
     */
    private RC() {
    }

    /**
     * Comprueba una máscara en una frontera de entrada; no convierte códigos
     * nativos externos.
     */
    public static boolean isValid(int value) {
        return value >= OK && value <= 0x7F;
    }

    /**
     * Clasifica máscaras válidas por sus bits de error, no por ser distintas de
     * cero.
     */
    public static boolean isError(int value) {
        return (value & (ERROR | SEVERE | FATAL)) != 0;
    }
}
