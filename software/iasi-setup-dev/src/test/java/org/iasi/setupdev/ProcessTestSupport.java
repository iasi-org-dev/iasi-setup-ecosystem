package org.iasi.setupdev;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.TimeUnit;
import org.iasi.common.operation.OperationResult;
import org.iasi.common.platform.Platform;

/**
 * Aísla cada invocación en otra JVM; no accede a campos privados ni reinicia el
 * Singleton.
 */
final class ProcessTestSupport {
    /** Utilidad de pruebas sin instancias. */
    private ProcessTestSupport() {
    }

    /**
     * Serializa solo datos del escenario; null representa un detector que debe
     * permanecer sin invocar.
     */
    static int run(String[] arguments, Path cwd, ByteArrayOutputStream out, ByteArrayOutputStream err, OperationResult<Platform> operation) throws Exception {
        String scenario = "FORBIDDEN";
        Platform platform = null;
        if (operation != null) {
            scenario = Integer.toString(operation.status());
            if (operation.value().isEmpty()) scenario = "EMPTY:" + scenario;
            platform = operation.value().orElse(null);
        }
        return runScenario(scenario, arguments, cwd, out, err, platform);
    }

    /**
     * Lanza un proceso, captura destinos separados y deja la evidencia fuera del
     * CWD sometido a prueba.
     */
    static int runScenario(String scenario, String[] arguments, Path cwd, ByteArrayOutputStream out, ByteArrayOutputStream err, Platform platform)
            throws Exception {
        Path evidence = Path.of("outputs/TASK-00.01.03/build/process-tests", UUID.randomUUID().toString()).toAbsolutePath();
        Files.createDirectories(evidence);
        List<String> command = command(evidence, platform);
        command.add(ReturnCodeProcessMain.class.getName());
        command.add(scenario);
        command.addAll(List.of(arguments));
        Process child = new ProcessBuilder(command).directory(cwd.toFile()).redirectOutput(evidence.resolve("stdout.txt").toFile())
                .redirectError(evidence.resolve("stderr.txt").toFile()).start();
        if (!child.waitFor(30, TimeUnit.SECONDS)) {
            child.destroyForcibly();
            throw new IOException("Test process timed out");
        }
        out.write(Files.readAllBytes(evidence.resolve("stdout.txt")));
        err.write(Files.readAllBytes(evidence.resolve("stderr.txt")));
        return child.exitValue();
    }

    /**
     * Construye argumentos sin concatenar comandos de shell y transmite propiedades
     * exclusivas del harness de QA.
     */
    private static List<String> command(Path evidence, Platform platform) {
        List<String> command = new ArrayList<>();
        command.add(Path.of(System.getProperty("java.home"), "bin", "java").toString());
        command.add("-Diasi.qa.context=" + evidence.resolve("context.txt"));
        if (platform != null) addPlatform(command, platform);
        command.add("-cp");
        command.add(System.getProperty("java.class.path"));
        return command;
    }

    /**
     * Transfiere valores inmutables, no objetos ni estados globales compartidos
     * entre ejecuciones.
     */
    private static void addPlatform(List<String> command, Platform platform) {
        command.add("-Diasi.qa.family=" + platform.family().name());
        command.add("-Diasi.qa.name=" + platform.name());
        command.add("-Diasi.qa.version=" + platform.version());
        command.add("-Diasi.qa.architecture=" + platform.architecture());
        command.add("-Diasi.qa.runtime=" + platform.runtime());
        command.add("-Diasi.qa.vendor=" + platform.vendor());
    }
}
