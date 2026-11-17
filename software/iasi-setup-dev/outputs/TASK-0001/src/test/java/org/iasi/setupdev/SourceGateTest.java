package org.iasi.setupdev;

import static org.junit.jupiter.api.Assertions.*;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.concurrent.TimeUnit;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

class SourceGateTest {
    @TempDir
    Path fixture;

    /**
     * Contrasta puntuaciones conocidas y comentarios sin confundirlos con literales
     * Java.
     */
    @Test
    void knownMetricsAndCommentCounting() throws Exception {
        String method = "int value() {\n    // comment\n    /* comment */ int number = 1;\n    String text = \"/* literal */\";\n    return number;\n}";
        assertEquals(0, check(method));
        assertTrue(Files.readString(fixture.resolve("qa/metrics.csv")).lines()
                .anyMatch(line -> line.startsWith("Fixture.java,value,") && line.endsWith(",5,0,1,0")));
    }

    /** Evita contabilizar una continuación else-if como un nuevo nivel anidado. */
    @Test
    void elseIfUsesOneNestingLevel() throws Exception {
        String method = "int value(boolean a, boolean b) {\n    if (a) return 1;\n    else if (b) return 2;\n    else return 3;\n}";
        assertEquals(0, check(method));
        assertTrue(Files.readString(fixture.resolve("qa/metrics.csv")).lines()
                .anyMatch(line -> line.startsWith("Fixture.java,value,") && line.endsWith(",5,1,3,4")));
    }

    /**
     * Introduce defectos de estilo y codificación para confirmar que el gate los
     * rechaza.
     */
    @Test
    void styleAndBomAreRejected() throws Exception {
        assertNotEquals(0, check("int value(boolean test) {\n    if (test) { return 1; }\n    return 0;\n}"));
        Path source = fixture.resolve("src/Fixture.java");
        Files.writeString(source, "\ufeff" + Files.readString(source), StandardCharsets.UTF_8);
        assertNotEquals(0, execute());
    }

    /**
     * Comprueba el límite de líneas efectivas mediante un método generado demasiado
     * largo.
     */
    @Test
    void rejectsLongMethods() throws Exception {
        assertNotEquals(0, check("void value() {\n" + "    System.nanoTime();\n".repeat(61) + "}"));
        assertTrue(Files.readString(fixture.resolve("result.log")).contains("length exceeds 60"));
    }

    /**
     * Introduce decisiones independientes suficientes para superar ambos máximos.
     */
    @Test
    void rejectsCyclomaticAndCognitiveExcess() throws Exception {
        assertNotEquals(0, check("void value(boolean test) {\n" + "    if (test) System.nanoTime();\n".repeat(16) + "}"));
        String output = Files.readString(fixture.resolve("result.log"));
        assertTrue(output.contains("cyclomatic exceeds 10"));
        assertTrue(output.contains("cognitive exceeds 15"));
    }

    /** Genera cuatro bucles anidados y exige el rechazo por profundidad. */
    @Test
    void rejectsDeepNesting() throws Exception {
        String method = "void value(boolean test) {\n" + "    while (test) {\n".repeat(4) + "        System.nanoTime();\n" + "    }\n".repeat(4) + "}";
        assertNotEquals(0, check(method));
        assertTrue(Files.readString(fixture.resolve("result.log")).contains("nesting exceeds 3"));
    }

    /**
     * Crea una fuente mínima y una copia del checker en scratch para probar
     * controles sin alterar el producto.
     */
    private int check(String method) throws Exception {
        Files.createDirectories(fixture.resolve("src"));
        Files.createDirectories(fixture.resolve("qa/tools"));
        Files.copy(Path.of("qa/tools/SourceGate.java"), fixture.resolve("qa/tools/SourceGate.java"));
        Files.writeString(fixture.resolve("src/Fixture.java"), "class Fixture {\n" + method + "\n}\n");
        return execute();
    }

    /**
     * Lanza el checker en otro proceso con tiempo acotado y conserva el diagnóstico
     * de la prueba.
     */
    private int execute() throws IOException, InterruptedException {
        String java = Path.of(System.getProperty("java.home"), "bin", "java").toString();
        Process child = new ProcessBuilder(java, fixture.resolve("qa/tools/SourceGate.java").toString(), fixture.toString()).redirectErrorStream(true)
                .redirectOutput(fixture.resolve("result.log").toFile()).start();
        assertTrue(child.waitFor(30, TimeUnit.SECONDS), "Checker timed out");
        return child.exitValue();
    }
}
