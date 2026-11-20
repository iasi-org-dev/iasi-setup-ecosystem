package org.iasi.common.logging;

import java.util.regex.Pattern;

/**
 * Removes control characters and recognizable credentials before text reaches log sinks.
 *
 * @author Javier G. Grandez
 * @since 0.1.0
 * @version 0.1.0
 * @history 2026-11-19 | 0.1.0 | Establish structural documentation and component responsibilities.
 */
final class Redactor {
    private static final Pattern SECRET = Pattern.compile("(?i)(password|passwd|token|secret|api[_-]?key)(\\s*[:=]\\s*)(\\\"[^\\\"]*\\\"|'[^']*'|[^\\s,;]+)");
    private static final Pattern AUTH = Pattern.compile("(?i)(bearer|basic)\\s+\\S+");
    private static final Pattern USER_INFO = Pattern.compile("(://)[^/@\\s]+:[^/@\\s]+@");

    private Redactor() {
    }

    static String sanitize(String text) {
        String clean = text.replaceAll("[\\p{Cntrl}\\p{Zl}\\p{Zp}]", " ");
        clean = SECRET.matcher(clean).replaceAll("$1$2[REDACTED]");
        clean = AUTH.matcher(clean).replaceAll("$1 [REDACTED]");
        return USER_INFO.matcher(clean).replaceAll("$1[REDACTED]@");
    }
}
