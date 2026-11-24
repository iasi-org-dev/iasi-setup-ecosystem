package org.iasi.args.model;

import org.iasi.args.loader.*;
import org.iasi.args.layer.*;
import org.iasi.args.validation.*;
/**
 * Identifies the data representation required when transforming a textual argument value.
 *
 * @author Javier G. Grandez
 * @since 0.1.0
 * @version 0.1.0
 * @history 2026-11-19 | 0.1.0 | Establish structural documentation and component responsibilities.
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
