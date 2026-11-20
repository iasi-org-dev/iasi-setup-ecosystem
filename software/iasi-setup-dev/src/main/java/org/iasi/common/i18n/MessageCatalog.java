package org.iasi.common.i18n;

import java.text.MessageFormat;
import java.util.Locale;
import java.util.ResourceBundle;

/**
 * Resolves localized message templates using an explicit resource bundle and locale.
 *
 * @author Javier G. Grandez
 * @since 0.1.0
 * @version 0.1.0
 * @history 2026-11-19 | 0.1.0 | Establish structural documentation and component responsibilities.
 */
public final class MessageCatalog {
    private final Locale locale;
    private final ResourceBundle bundle;

    public MessageCatalog(String bundleName, Locale locale) {
        this.locale = locale;
        this.bundle = ResourceBundle.getBundle(bundleName, locale, ResourceBundle.Control.getNoFallbackControl(ResourceBundle.Control.FORMAT_PROPERTIES));
    }

    public String text(String key, Object... arguments) {
        return new MessageFormat(bundle.getString(key), locale).format(arguments);
    }
}
