package org.iasi.setupdev;

import java.io.PrintStream;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.Clock;
import java.util.Arrays;
import java.util.Locale;
import java.util.Optional;
import java.util.function.Supplier;
import org.iasi.base.RC;
import org.iasisetupdev.core.Context;
import org.iasi.common.operation.OperationResult;
import org.iasi.common.platform.Platform;

/**
 * Entry point de QA; cada proceso contiene una sola ejecución real y un solo
 * contexto.
 */
public final class ReturnCodeProcessMain {
    /** Clase de entrada sin instancias ni estado de dominio. */
    private ReturnCodeProcessMain() {
    }

    /**
     * Inyecta la operación de prueba y termina únicamente después de que el
     * pipeline y el logging hayan cerrado.
     */
    public static void main(String[] arguments) throws Exception {
        PrintStream out = new PrintStream(System.out, true, StandardCharsets.UTF_8);
        PrintStream err = new PrintStream(System.err, true, StandardCharsets.UTF_8);
        int rc = Main.runOperation(Arrays.copyOfRange(arguments, 1, arguments.length), Path.of(System.getProperty("user.dir")), out, err, Locale.ENGLISH,
                Clock.systemUTC(), false, new Probe(arguments[0]));
        reportContext();
        System.exit(rc);
    }

    /**
     * Conserva evidencia de publicación sin contaminar las salidas de consola que
     * comprueban los tests heredados.
     */
    private static void reportContext() throws Exception {
        String target = System.getProperty("iasi.qa.context");
        if (target == null) return;
        String state;
        try {
            Context ctx = Context.getInstance();
            state = "published=true\nrc=" + ctx.getRC() + "\nid=" + ctx.executionId() + "\n";
        } catch (IllegalStateException exception) {
            state = "published=false\n";
        }
        Files.writeString(Path.of(target), state, StandardCharsets.UTF_8);
    }

    private static final class Probe implements Supplier<OperationResult<Platform>> {
        private final String scenario;

        /**
         * Mantiene solo la definición local del escenario, nunca un segundo contexto
         * global.
         */
        private Probe(String scenario) {
            this.scenario = scenario;
        }

        /**
         * Produce metadatos explícitos; los errores sintéticos prueban cierre y
         * conservación de bits anteriores.
         */
        @Override
        public OperationResult<Platform> get() {
            if (scenario.equals("FORBIDDEN")) throw new AssertionError("Probe must not run");
            if (scenario.equals("INFO_THEN_FAILURE")) {
                Context ctx = Context.getInstance();
                ctx.setRC(RC.INFO);
                throw new IllegalStateException("Synthetic failure with token=must-not-leak");
            }
            boolean empty = scenario.startsWith("EMPTY:");
            String expression = empty ? scenario.substring(6) : scenario;
            int rc = parseMask(expression);
            if (empty || (rc & RC.NOTHING_TO_DO) != 0) return new OperationResult<>(Optional.empty(), rc);
            return OperationResult.withValue(platform(), rc);
        }

        /**
         * Traduce nombres de constantes del protocolo de QA; no interpreta códigos
         * nativos de otros programas.
         */
        private int parseMask(String expression) {
            if (expression.matches("[0-9]+")) return Integer.parseInt(expression);
            int rc = RC.OK;
            try {
                for (String name : expression.split("\\+"))
                    rc |= RC.class.getField(name).getInt(null);
            } catch (ReflectiveOperationException exception) {
                throw new IllegalArgumentException("Invalid QA scenario", exception);
            }
            return rc;
        }

        /**
         * Recupera una instantánea de prueba o usa el host real cuando no se ha
         * inyectado otra plataforma.
         */
        private Platform platform() {
            String name = System.getProperty("iasi.qa.name");
            if (name == null) return Platform.detect();
            return new Platform(Platform.Family.valueOf(System.getProperty("iasi.qa.family")), name, System.getProperty("iasi.qa.version"),
                    System.getProperty("iasi.qa.architecture"), System.getProperty("iasi.qa.runtime"), System.getProperty("iasi.qa.vendor"));
        }
    }
}
