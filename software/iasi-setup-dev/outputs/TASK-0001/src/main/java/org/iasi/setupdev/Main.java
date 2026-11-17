package org.iasi.setupdev;

import java.io.IOException;
import java.io.PrintStream;
import java.nio.charset.StandardCharsets;
import java.nio.file.Path;
import java.time.Clock;
import java.util.Locale;
import java.util.function.Supplier;
import org.iasi.common.i18n.MessageCatalog;
import org.iasi.common.logging.Logger;
import org.iasi.common.logging.Loggers;
import org.iasi.common.platform.Platform;

public final class Main {
    /**
     * Punto de entrada estático; los colaboradores se inyectan en run para
     * verificar el comportamiento.
     */
    private Main() {
    }

    /**
     * Captura el contexto inicial, configura salida UTF-8 y entrega al proceso el
     * código final de la ejecución.
     */
    public static void main(String[] arguments) {
        PrintStream out = new PrintStream(System.out, true, StandardCharsets.UTF_8);
        PrintStream err = new PrintStream(System.err, true, StandardCharsets.UTF_8);
        int result = run(arguments, Path.of(System.getProperty("user.dir")), out, err, Locale.getDefault(), Clock.systemDefaultZone(), consoleColors(),
                Platform::detect);
        System.exit(result);
    }

    /**
     * Habilita ANSI solo cuando hay consola e indicios de soporte, respetando
     * NO_COLOR.
     */
    private static boolean consoleColors() {
        if (System.console() == null || System.getenv("NO_COLOR") != null) return false;
        String terminal = System.getenv("TERM");
        boolean supported = terminal != null && terminal.matches("(?i).*(xterm|color|vt100|ansi|screen|tmux).*");
        return supported || System.getenv("WT_SESSION") != null || System.getenv("ANSICON") != null;
    }

    /**
     * Coordina análisis, ayuda o configuración y ejecución; traduce errores de
     * entrada e IO en códigos sin efectos parciales.
     */
    static int run(String[] arguments, Path cwd, PrintStream out, PrintStream err, Locale locale, Clock clock, boolean colors, Supplier<Platform> detector) {
        MessageCatalog catalog = new MessageCatalog("org.iasi.setupdev.messages", locale);
        try {
            Options options = Options.parse(arguments);
            Command command = Command.resolve(options.words());
            if (command.help(options)) {
                Help.show(command, catalog, out);
                return 0;
            }
            var internal = Main.class.getResourceAsStream("/org/iasi/setupdev/defaults.toml");
            Settings settings = Configuration.resolve(options, cwd, internal);
            return execute(command, settings, catalog, clock, out, err, colors, detector);
        } catch (InputException exception) {
            Logger.earlyError(catalog, err, clock, Event.INPUT_ERROR, catalog.text(exception.getMessage()));
            return 2;
        } catch (IOException | SecurityException exception) {
            Logger.earlyError(catalog, err, clock, Event.IO_ERROR);
            return 1;
        }
    }

    /**
     * Abre el servicio común, registra inicio y rutas, ejecuta el diagnóstico y
     * resume el resultado antes del cierre.
     */
    private static int execute(Command command, Settings settings, MessageCatalog catalog, Clock clock, PrintStream out, PrintStream err, boolean colors,
            Supplier<Platform> detector) throws IOException {
        try (Logger messages = Loggers.open(catalog, clock, settings.verbosity(), out, err, colors, Boolean.getBoolean("iasi.log.trace"), settings.logs(),
                "iasi-setup-dev", "launcher")) {
            messages.emit(Event.START, command.syntax());
            messages.emit(Event.PATHS, settings.cwd(), settings.definitions(), settings.machines(), settings.logs(), settings.force());
            int result = dispatch(command, messages, detector);
            messages.emit(Event.FINISH, result);
            return result;
        }
    }

    /**
     * Ejecuta únicamente capacidades implementadas; SO desconocido o acciones
     * futuras producen error sin SUCCESS.
     */
    private static int dispatch(Command command, Logger messages, Supplier<Platform> detector) throws IOException {
        if (!command.executable()) {
            messages.emit(Event.UNAVAILABLE, command.syntax());
            return 2;
        }
        Platform platform = detector.get();
        messages.emit(Event.PLATFORM, platform.family(), platform.name(), platform.version(), platform.architecture());
        messages.emit(Event.RUNTIME, platform.runtime(), platform.vendor());
        if (platform.family() == Platform.Family.UNKNOWN) {
            messages.emit(Event.UNKNOWN_HOST);
            return 3;
        }
        messages.emit(Event.VERIFIED);
        return 0;
    }
}
