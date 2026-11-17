package org.iasi.setupdev;

import static org.junit.jupiter.api.Assertions.*;

import java.io.ByteArrayOutputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Optional;
import java.util.concurrent.TimeUnit;
import org.iasi.base.RC;

import org.iasi.common.operation.OperationResult;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;

class ReturnCodeIntegrationTest {
    @TempDir
    Path cwd;

    /**
     * Una operación normal emite progreso INFO y SUCCESS sin marcar el indicador RC
     * Info.
     */
    @Test
    void progressAndConsoleFiltersDoNotChangeStatus() {
        var output = new ByteArrayOutputStream();
        assertEquals(0, run(OperationResult.completed(PlatformTest.detect("Linux")), output, "platform", "-V"));
        assertTrue(output.toString().contains("SYS01001"));
        assertTrue(output.toString().contains("SYS01005"));
        assertEquals(0, run(OperationResult.completed(PlatformTest.detect("Linux")), new ByteArrayOutputStream(), "platform", "-s"));
    }

    /**
     * La circunstancia informativa procede de la operación y se conserva aunque la
     * consola sea silenciosa.
     */
    @Test
    void relevantInformationIsExplicitAndNonErroneous() {
        var operation = OperationResult.withValue(PlatformTest.detect("Linux"), RC.INFO);
        var output = new ByteArrayOutputStream();
        assertEquals(2, run(operation, output, "platform", "-s"));
        assertTrue(output.toString().isEmpty());
        assertFalse(RC.isError(operation.status()));
    }

    /**
     * La ausencia real de resultado no fabrica un diagnóstico exitoso ni pierde
     * otras circunstancias.
     */
    @Test
    void noApplicableWorkAccumulatesWithoutFalseSuccess() {
        var output = new ByteArrayOutputStream();
        assertEquals(1, run(OperationResult.nothingToDo(), output, "platform"));
        assertFalse(output.toString().contains("SYS01005"));
        var combined = new OperationResult<org.iasi.common.platform.Platform>(Optional.empty(), RC.INFO);
        assertEquals(3, run(combined, new ByteArrayOutputStream(), "platform"));
    }

    /**
     * Un error local del host se agrega al Info previo en vez de sustituirlo por
     * otro valor.
     */
    @Test
    void localFailurePreservesChildCircumstances() {
        var operation = OperationResult.withValue(PlatformTest.detect("unknown"), RC.INFO);
        assertEquals(18, run(operation, new ByteArrayOutputStream(), "platform"));
    }

    /**
     * Comprueba el exit status del proceso completo con cada bit y varias
     * combinaciones, sin traducción secuencial.
     */
    @ParameterizedTest
    @CsvSource({"OK,0", "NOTHING_TO_DO,1", "INFO,2", "WARNING,4", "ATTENTION,8", "ERROR,16", "SEVERE,32", "FATAL,64", "INFO+WARNING,6", "WARNING+ATTENTION,12",
            "ERROR+WARNING,20", "INFO+ERROR,18", "INFO+INFO,2", "NOTHING_TO_DO+INFO+WARNING+ATTENTION+ERROR+SEVERE+FATAL,127"})
    void actualProcessExitMatchesAccumulatedRc(String scenario, int expected) throws Exception {
        Path directory = Files.createDirectory(cwd.resolve("process"));
        String java = Path.of(System.getProperty("java.home"), "bin", "java").toString();
        Process child = new ProcessBuilder(java, "-cp", System.getProperty("java.class.path"), ReturnCodeProcessMain.class.getName(), scenario, "platform",
                "--logs", directory.toString()).directory(directory.toFile()).redirectErrorStream(true)
                .redirectOutput(directory.resolve("console.txt").toFile()).start();
        assertTrue(child.waitFor(30, TimeUnit.SECONDS));
        assertEquals(expected, child.exitValue());
    }

    /**
     * Ejecuta la misma coordinación del producto con una operación controlada y
     * reloj fijo.
     */
    private int run(OperationResult<org.iasi.common.platform.Platform> operation, ByteArrayOutputStream output, String... arguments) {
        try {
            return ProcessTestSupport.run(arguments, cwd, output, new ByteArrayOutputStream(), operation);
        } catch (Exception exception) {
            throw new AssertionError("Cannot execute isolated operation", exception);
        }
    }
}
