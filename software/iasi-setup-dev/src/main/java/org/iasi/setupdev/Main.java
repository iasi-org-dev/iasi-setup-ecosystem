package org.iasi.setupdev;

import java.io.IOException;
import java.io.PrintStream;
import java.nio.charset.StandardCharsets;
import java.nio.file.Path;
import java.time.Clock;
import java.util.Locale;
import java.util.function.Supplier;
import org.iasi.base.RC;
import org.iasisetupdev.core.ExecutionConfiguration;
import org.iasisetupdev.core.Context;
import org.iasi.common.i18n.MessageCatalog;
import org.iasi.common.logging.Logger;
import org.iasi.common.logging.Loggers;
import org.iasi.common.operation.OperationResult;
import org.iasi.common.platform.Platform;

public final class Main {
    /**
     * Entrada estática de una sola ejecución por JVM; las pruebas de otras
     * ejecuciones utilizan procesos aislados.
     */
    private Main() {
    }

    /**
     * Termina una única vez, después del cierre de recursos y con el RC final
     * acumulado.
     */
    public static void main(String[] arguments) {
        PrintStream out = new PrintStream(System.out, true, StandardCharsets.UTF_8);
        PrintStream err = new PrintStream(System.err, true, StandardCharsets.UTF_8);
        int rc = runOperation(arguments, Path.of(System.getProperty("user.dir")), out, err, Locale.getDefault(), Clock.systemDefaultZone(), consoleColors(),
                Platform::identify);
        System.exit(rc);
    }

    /**
     * Decide soporte ANSI en el límite del ejecutable, respetando la consola y
     * NO_COLOR.
     */
    private static boolean consoleColors() {
        if (System.console() == null || System.getenv("NO_COLOR") != null) return false;
        String terminal = System.getenv("TERM");
        boolean supported = terminal != null && terminal.matches("(?i).*(xterm|color|vt100|ansi|screen|tmux).*");
        return supported || System.getenv("WT_SESSION") != null || System.getenv("ANSICON") != null;
    }

    /**
     * Resuelve bootstrap antes de publicar ctx; los fallos previos utilizan un RC
     * local, no un contexto parcial.
     */
    static int runOperation(String[] arguments, Path cwd, PrintStream out, PrintStream err, Locale locale, Clock clock, boolean colors,
            Supplier<OperationResult<Platform>> detector) {
        Context ctx = null;
        int bootstrapRC = RC.OK;
        MessageCatalog catalog = new MessageCatalog("org.iasi.setupdev.messages", locale);
        try {
            Options options = Options.parse(arguments);
            Command command = Command.resolve(options.words());
            if (command.help(options)) {
                Help.show(command, catalog, out);
                return bootstrapRC;
            }
            var internal = Main.class.getResourceAsStream("/org/iasi/setupdev/defaults.toml");
            ExecutionConfiguration configuration = Configuration.resolve(options, cwd, internal);
            ctx = Context.initialize(configuration);
            execute(ctx, command, catalog, clock, out, err, colors, detector);
        } catch (InputException exception) {
            bootstrapRC |= RC.ERROR;
            if (ctx != null) ctx.setRC(RC.ERROR);
            Logger.earlyError(catalog, err, clock, Event.INPUT_ERROR, catalog.text(exception.getMessage()));
        } catch (IOException | SecurityException exception) {
            bootstrapRC |= RC.ERROR;
            if (ctx != null) ctx.setRC(RC.ERROR);
            Logger.earlyError(catalog, err, clock, Event.IO_ERROR);
        } catch (RuntimeException exception) {
            bootstrapRC |= RC.FATAL;
            if (ctx != null) ctx.setRC(RC.FATAL);
            Logger.earlyError(catalog, err, clock, Event.UNEXPECTED_FAILURE);
        }
        return ctx == null ? bootstrapRC : ctx.getRC();
    }

    /**
     * Abre los servicios locales y utiliza ctx como fuente única de configuración y
     * RC durante la operación.
     */
    private static void execute(Context ctx, Command command, MessageCatalog catalog, Clock clock, PrintStream out, PrintStream err, boolean colors,
            Supplier<OperationResult<Platform>> detector) throws IOException {
        ExecutionConfiguration configuration = ctx.configuration();
        try (Logger messages = Loggers.open(catalog, clock, configuration.verbosity(), out, err, colors, Boolean.getBoolean("iasi.log.trace"),
                configuration.logs(), "iasi-setup-dev", "launcher")) {
            messages.emit(Event.START, command.syntax());
            reportPaths(ctx, messages);
            dispatch(ctx, command, messages, detector);
            messages.emit(Event.FINISH, ctx.getRC());
        }
    }

    /**
     * Presenta atributos estables del contexto sin convertir un mensaje de
     * diagnóstico en una incidencia RC.
     */
    private static void reportPaths(Context ctx, Logger messages) throws IOException {
        ExecutionConfiguration configuration = ctx.configuration();
        messages.emit(Event.PATHS, configuration.cwd(), configuration.definitions(), configuration.machines(), configuration.logs(), configuration.force());
    }

    /**
     * Agrega incidencias donde se detectan; continuar, retornar y presentar éxitos
     * son decisiones funcionales separadas.
     */
    private static void dispatch(Context ctx, Command command, Logger messages, Supplier<OperationResult<Platform>> detector) throws IOException {
        if (!command.executable()) {
            ctx.setRC(RC.ERROR);
            messages.emit(Event.UNAVAILABLE, command.syntax());
            return;
        }
        OperationResult<Platform> result = detector.get();
        ctx.setRC(result.status());
        if (result.value().isEmpty()) {
            ctx.setRC(RC.NOTHING_TO_DO);
            return;
        }
        Platform platform = result.value().orElseThrow();
        messages.emit(Event.PLATFORM, platform.family(), platform.name(), platform.version(), platform.architecture());
        messages.emit(Event.RUNTIME, platform.runtime(), platform.vendor());
        if (platform.family() == Platform.Family.UNKNOWN) {
            ctx.setRC(RC.ERROR);
            messages.emit(Event.UNKNOWN_HOST);
            return;
        }
        if (!RC.isError(ctx.getRC())) messages.emit(Event.VERIFIED);
    }
}
