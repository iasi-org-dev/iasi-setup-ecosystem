package org.iasi.setupdev;

import static org.junit.jupiter.api.Assertions.*;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.concurrent.TimeUnit;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

/**
 * Exercises source metrics and style checks using isolated synthetic Java fixtures.
 *
 * @author Javier G. Grandez
 * @since 0.1.0
 * @version 0.1.0
 * @history 2026-11-19 | 0.1.0 | Establish structural documentation and component responsibilities.
 */
class SourceGateTest {
    @TempDir
    Path fixture;

    @Test
    void knownMetricsAndCommentCounting() throws Exception {
        String method = "int value() {\n    // comment\n    /* comment */ int number = 1;\n    String text = \"/* literal */\";\n    return number;\n}";
        assertEquals(0, check(method));
        assertTrue(Files.readString(fixture.resolve("qa/metrics.csv")).lines()
                .anyMatch(line -> line.startsWith("Fixture.java,value,") && line.endsWith(",5,0,1,0")));
    }

    @Test
    void elseIfUsesOneNestingLevel() throws Exception {
        String method = "int value(boolean a, boolean b) {\n    if (a) return 1;\n    else if (b) return 2;\n    else return 3;\n}";
        assertEquals(0, check(method));
        assertTrue(Files.readString(fixture.resolve("qa/metrics.csv")).lines()
                .anyMatch(line -> line.startsWith("Fixture.java,value,") && line.endsWith(",5,1,3,4")));
    }

    @Test
    void styleAndBomAreRejected() throws Exception {
        assertNotEquals(0, check("int value(boolean test) {\n    if (test) { return 1; }\n    return 0;\n}"));
        Path source = fixture.resolve("src/Fixture.java");
        Files.writeString(source, "\ufeff" + Files.readString(source), StandardCharsets.UTF_8);
        assertNotEquals(0, execute());
    }

    @Test
    void rejectsLongMethods() throws Exception {
        assertNotEquals(0, check("void value() {\n" + "    System.nanoTime();\n".repeat(61) + "}"));
        assertTrue(Files.readString(fixture.resolve("result.log")).contains("length exceeds 60"));
    }

    @Test
    void rejectsCyclomaticAndCognitiveExcess() throws Exception {
        assertNotEquals(0, check("void value(boolean test) {\n" + "    if (test) System.nanoTime();\n".repeat(16) + "}"));
        String output = Files.readString(fixture.resolve("result.log"));
        assertTrue(output.contains("cyclomatic exceeds 10"));
        assertTrue(output.contains("cognitive exceeds 15"));
    }

    @Test
    void rejectsDeepNesting() throws Exception {
        String method = "void value(boolean test) {\n" + "    while (test) {\n".repeat(4) + "        System.nanoTime();\n" + "    }\n".repeat(4) + "}";
        assertNotEquals(0, check(method));
        assertTrue(Files.readString(fixture.resolve("result.log")).contains("nesting exceeds 3"));
    }

    private int check(String method) throws Exception {
        Files.createDirectories(fixture.resolve("src"));
        Files.createDirectories(fixture.resolve("qa/tools"));
        Files.copy(Path.of("outputs/TASK-00.01.07/qa/tools/SourceGate.java"), fixture.resolve("qa/tools/SourceGate.java"));
        Files.writeString(fixture.resolve("src/Fixture.java"), "class Fixture {\n" + method + "\n}\n");
        return execute();
    }

    private int execute() throws IOException, InterruptedException {
        String java = Path.of(System.getProperty("java.home"), "bin", "java").toString();
        Process child = new ProcessBuilder(java, fixture.resolve("qa/tools/SourceGate.java").toString(), fixture.toString()).redirectErrorStream(true)
                .redirectOutput(fixture.resolve("result.log").toFile()).start();
        assertTrue(child.waitFor(30, TimeUnit.SECONDS), "Checker timed out");
        return child.exitValue();
    }
}
