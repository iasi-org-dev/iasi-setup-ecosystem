package org.iasi.common.logging;

/**
 * Contrato de un mensaje; cada aplicación conserva su catálogo y sus
 * identificadores.
 */
public interface MessageDefinition {
    /** Identificador estable e independiente del idioma, con formato LLLNNMMM. */
    String code();

    /** Severidad semántica; los filtros de salida no deben modificarla. */
    Severity severity();

    /** Clave de la plantilla traducible dentro del catálogo de la aplicación. */
    String key();
}
