package org.iasi.common.logging;

/**
 * Describes a localized event independently of its logging backend.
 *
 * @author Javier G. Grandez
 * @since 0.1.0
 * @version 0.1.0
 * @history 2026-11-19 | 0.1.0 | Establish structural documentation and component responsibilities.
 */
public interface MessageDefinition {

    String code();

    Severity severity();

    String key();
}
