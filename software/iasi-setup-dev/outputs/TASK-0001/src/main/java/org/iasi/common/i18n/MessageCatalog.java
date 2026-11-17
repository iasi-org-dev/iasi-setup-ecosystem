package org.iasi.common.i18n;

import java.text.MessageFormat;
import java.util.Locale;
import java.util.ResourceBundle;

public final class MessageCatalog {
    private final Locale locale;
    private final ResourceBundle bundle;

    /**
     * Carga el catálogo indicado para el locale solicitado; el bundle base
     * proporciona el fallback sin depender de la aplicación.
     */
    public MessageCatalog(String bundleName, Locale locale) {
        this.locale = locale;
        this.bundle = ResourceBundle.getBundle(bundleName, locale, ResourceBundle.Control.getNoFallbackControl(ResourceBundle.Control.FORMAT_PROPERTIES));
    }

    /**
     * Interpola una plantilla completa con MessageFormat; una clave ausente se
     * propaga como error de catálogo.
     */
    public String text(String key, Object... arguments) {
        return new MessageFormat(bundle.getString(key), locale).format(arguments);
    }
}
