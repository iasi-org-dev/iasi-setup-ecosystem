package org.iasi.setupdev;

import static org.junit.jupiter.api.Assertions.*;

import java.nio.file.Files;
import java.nio.file.Path;
import java.util.concurrent.TimeUnit;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

/**
 * Checks structural documentation failures without demanding comments on self-explanatory methods.
 *
 * @author Javier G. Grandez
 * @since 0.1.0
 * @version 0.1.0
 * @history 2026-11-19 | 0.1.0 | Add regression checks for the corporate Javadoc contract.
 */
class JavadocGateTest {
    @TempDir
    Path fixture;

    @Test
    void permitsUndocumentedMethodsWhenPackageAndTypeContractsExist() throws Exception {
        writeFixture(true, false);
        assertEquals(0, runGate());
    }

    @Test
    void rejectsMissingPackageDocumentation() throws Exception {
        writeFixture(false, false);
        assertNotEquals(0, runGate());
        assertTrue(Files.readString(fixture.resolve("qa/javadoc-structure.txt")).contains("package-info.java"));
    }

    @Test
    void checksNestedTypesAsWellAsPublicTypes() throws Exception {
        writeFixture(true, true);
        assertNotEquals(0, runGate());
        assertTrue(Files.readString(fixture.resolve("qa/javadoc-structure.txt")).contains("Nested: missing descriptive type Javadoc"));
    }

    private void writeFixture(boolean packageDocumented, boolean nested) throws Exception {
        Path sources = fixture.resolve("src/main/java/example");
        Files.createDirectories(sources);
        if (packageDocumented) Files.writeString(sources.resolve("package-info.java"), "/** Exercises a synthetic data fixture. */\npackage example;\n");
        String header = "/**\n * Holds synthetic fixture data.\n * @author Fixture maintainer\n * @since 0.1.0\n * @version 0.1.0\n * @history 2026-11-19 | 0.1.0 | Create fixture.\n */\n";
        String body = nested ? "static class Nested {}" : "public int value() { return 1; }";
        Files.writeString(sources.resolve("Fixture.java"), "package example;\n" + header + "public class Fixture { " + body + " }\n");
    }

    private int runGate() throws Exception {
        Path tool = Path.of("outputs/TASK-00.01.06/qa/tools/JavadocGate.java").toAbsolutePath();
        Path java = Path.of(System.getProperty("java.home"), "bin", "java");
        Process process = new ProcessBuilder(java.toString(), tool.toString(), fixture.toString(), fixture.toString(), "--structure-only")
                .redirectErrorStream(true).redirectOutput(fixture.resolve("gate.log").toFile()).start();
        assertTrue(process.waitFor(30, TimeUnit.SECONDS));
        return process.exitValue();
    }
}
