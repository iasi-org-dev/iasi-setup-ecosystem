package org.iasi.setupdev.messages;

import org.iasi.setupdev.core.Context;

import java.time.Clock;
import java.util.Locale;
import org.iasi.base.RC;
import org.iasi.base.Verbosity;
import org.iasi.common.i18n.MessageCatalog;
import org.iasi.common.logging.ConsoleSink;
import org.iasi.common.logging.Severity;

/**
 * Reports application initialization diagnostics and terminates failed initialization with the accumulated return code.
 *
 * @author Javier G. Grandez
 * @since 0.1.0
 * @version 0.1.0
 * @history 2026-11-19 | 0.1.0 | Establish structural documentation and component responsibilities.
 * @history 2026-11-19 | 0.1.0 | Support direct localized error diagnostics during initialization.
 * @history 2026-11-20 | 0.1.0 | Report shutdown cleanup failures without recursively terminating the JVM.
 */
public final class InitializationMessages {
    private static final Context        CTX     = Context.getInstance();
    private static final Clock          CLOCK   = Clock.systemDefaultZone();
    private static final MessageCatalog CATALOG = new MessageCatalog("messages.messages", Locale.getDefault());
    private static final ConsoleSink    CONSOLE = new ConsoleSink(CTX.out(), CTX.err(), Verbosity.NORMAL, System.console() != null);

    private InitializationMessages() {
    }

    public static void inputError(String key) {
        stop(RC.ERROR, CATALOG.text("inputError", CATALOG.text(key)));
    }

    public static void error(String key) {
        stop(RC.ERROR, CATALOG.text(key));
    }

    public static void reportError(String key) {
        CTX.setRC(RC.ERROR);
        CONSOLE.write(Severity.ERROR, CATALOG.text(key), CLOCK);
    }

    public static void ioError() {
        stop(RC.ERROR, CATALOG.text("ioError"));
    }

    public static void unexpectedFailure() {
        stop(RC.FATAL, CATALOG.text("unexpectedFailure"));
    }

    public static void warning(String key, Object... arguments) {
        CTX.setRC(RC.WARNING);
        CONSOLE.write(Severity.WARNING, CATALOG.text(key, arguments), CLOCK);
    }

    private static void stop(int rc, String message) {
        CTX.setRC(rc);
        CONSOLE.write(Severity.ERROR, message, CLOCK);
        System.exit(CTX.getRC());
    }
}
