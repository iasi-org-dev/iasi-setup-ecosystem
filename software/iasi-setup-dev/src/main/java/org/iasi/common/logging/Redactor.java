package org.iasi.common.logging;

import java.util.regex.Pattern;

final class Redactor {
    private static final Pattern SECRET = Pattern.compile("(?i)(password|passwd|token|secret|api[_-]?key)(\\s*[:=]\\s*)(\\\"[^\\\"]*\\\"|'[^']*'|[^\\s,;]+)");
    private static final Pattern AUTH = Pattern.compile("(?i)(bearer|basic)\\s+\\S+");
    private static final Pattern USER_INFO = Pattern.compile("(://)[^/@\\s]+:[^/@\\s]+@");

    /**
     * Utilidad interna sin instancias; el saneado se aplica en la fachada antes de
     * distribuir eventos.
     */
    private Redactor() {
    }

    /**
     * Elimina controles y oculta patrones de credenciales antes de que cualquier
     * destino reciba el texto.
     */
    static String sanitize(String text) {
        String clean = text.replaceAll("[\\p{Cntrl}\\p{Zl}\\p{Zp}]", " ");
        clean = SECRET.matcher(clean).replaceAll("$1$2[REDACTED]");
        clean = AUTH.matcher(clean).replaceAll("$1 [REDACTED]");
        return USER_INFO.matcher(clean).replaceAll("$1[REDACTED]@");
    }
}
