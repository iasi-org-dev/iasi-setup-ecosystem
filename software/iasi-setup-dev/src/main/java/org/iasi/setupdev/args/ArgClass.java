package org.iasi.setupdev.args;

/**
 * Tipos de datos que puede declarar un argumento del programa.
 */
public enum ArgClass {
     BOOLEAN   // Boolean
    ,NATURAL   // Entero mayor que cero
    ,INTEGER   // Entero
    ,FLOAT     // Real
    ,STRING    // Cadena
    ,FILE      // Fichero
    ,DIRECTORY // Directorio
    ,URL       // URN / URI
    ,MAIL      // Correo
    ,DATE      // Fecha
    ,TIME      // Hora
    ,TMS       // Timestamp
}
