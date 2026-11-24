import com.sun.source.doctree.BlockTagTree;
import com.sun.source.doctree.DocCommentTree;
import com.sun.source.tree.ClassTree;
import com.sun.source.tree.CompilationUnitTree;
import com.sun.source.util.DocTrees;
import com.sun.source.util.JavacTask;
import com.sun.source.util.TreePath;
import com.sun.source.util.TreePathScanner;
import java.io.IOException;
import java.io.StringWriter;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import javax.tools.Diagnostic;
import javax.tools.DiagnosticCollector;
import javax.tools.JavaFileObject;
import javax.tools.ToolProvider;

/**
 * Enforces package and named-type documentation without requiring method-level coverage.
 *
 * @author Javier G. Grandez
 * @since 0.1.0
 * @version 0.1.0
 * @history 2026-11-19 | 0.1.0 | Add structural documentation checks and history-aware Javadoc generation.
 */
class JavadocGate {
    private final List<String> errors = new ArrayList<>();
    private final Set<String> packages = new HashSet<>();
    private int types;

    public static void main(String[] arguments) throws Exception {
        Path root = Path.of(arguments[0]);
        Path output = Path.of(arguments[1]);
        JavadocGate gate = new JavadocGate();
        gate.checkStructure(root);
        Files.createDirectories(output.resolve("qa"));
        gate.writeReport(output);
        if (!gate.errors.isEmpty()) throw new IllegalStateException("Javadoc structure failed: " + gate.errors.size());
        if (arguments.length < 3 || !arguments[2].equals("--structure-only")) gate.generate(root, output);
    }

    private void checkStructure(Path root) throws IOException {
        List<Path> sources;
        try (var files = Files.walk(root.resolve("src"))) {
            sources = files.filter(path -> path.toString().endsWith(".java")).sorted().toList();
        }
        var compiler = ToolProvider.getSystemJavaCompiler();
        var diagnostics = new DiagnosticCollector<JavaFileObject>();
        try (var manager = compiler.getStandardFileManager(diagnostics, null, StandardCharsets.UTF_8)) {
            var files = manager.getJavaFileObjectsFromPaths(sources);
            JavacTask task = (JavacTask) compiler.getTask(null, manager, diagnostics, List.of("-proc:none"), null, files);
            List<CompilationUnitTree> units = new ArrayList<>();
            task.parse().forEach(units::add);
            inspectUnits(units, DocTrees.instance(task));
        }
        for (var diagnostic : diagnostics.getDiagnostics()) {
            if (diagnostic.getKind() == Diagnostic.Kind.ERROR) errors.add(diagnostic.toString());
        }
    }

    private void inspectUnits(List<CompilationUnitTree> units, DocTrees documentation) {
        Set<String> describedPackages = new HashSet<>();
        for (CompilationUnitTree unit : units) {
            if (unit.getPackageName() != null) packages.add(unit.getPackageName().toString());
            if (unit.getSourceFile().getName().endsWith("package-info.java"))
                inspectPackage(unit, documentation, describedPackages);
            inspectTypes(unit, documentation);
        }
        for (String name : packages) {
            if (!describedPackages.contains(name)) errors.add(name + ": missing descriptive package-info.java");
        }
    }

    private void inspectPackage(CompilationUnitTree unit, DocTrees documentation, Set<String> described) {
        if (unit.getPackageName() == null) return;
        DocCommentTree comment = documentation.getDocCommentTree(TreePath.getPath(unit, unit.getPackage()));
        if (hasDescription(comment)) described.add(unit.getPackageName().toString());
    }

    private void inspectTypes(CompilationUnitTree unit, DocTrees documentation) {
        new TreePathScanner<Void, Void>() {
            @Override
            public Void visitClass(ClassTree type, Void unused) {
                if (!type.getSimpleName().isEmpty()) {
                    types++;
                    String name = unit.getSourceFile().getName() + ": " + type.getSimpleName();
                    inspectType(name, documentation.getDocCommentTree(getCurrentPath()));
                }
                return super.visitClass(type, unused);
            }
        }.scan(unit, null);
    }

    private void inspectType(String name, DocCommentTree comment) {
        if (!hasDescription(comment)) {
            errors.add(name + ": missing descriptive type Javadoc");
            return;
        }
        Map<String, List<String>> tags = tags(comment);
        for (String tag : List.of("author", "since", "version", "history")) {
            if (!tags.containsKey(tag) || tags.get(tag).stream().allMatch(String::isBlank)) errors.add(name + ": missing @" + tag);
        }
        for (String since : tags.getOrDefault("since", List.of())) {
            if (!since.matches("\\d+\\.\\d+(?:\\.\\d+)?(?:[-+][\\w.-]+)?")) errors.add(name + ": @since must be a version");
        }
        for (String history : tags.getOrDefault("history", List.of())) {
            if (!history.matches("\\d{4}-\\d{2}-\\d{2}\\s*\\|\\s*\\S+\\s*\\|\\s*.+")) errors.add(name + ": invalid @history entry");
        }
    }

    private boolean hasDescription(DocCommentTree comment) {
        return comment != null && comment.getFullBody().stream().anyMatch(part -> !part.toString().isBlank());
    }

    private Map<String, List<String>> tags(DocCommentTree comment) {
        Map<String, List<String>> tags = new HashMap<>();
        for (var tree : comment.getBlockTags()) {
            if (tree instanceof BlockTagTree tag) {
                String value = tree.toString().replaceFirst("^@\\w+\\s*", "").strip();
                tags.computeIfAbsent(tag.getTagName(), ignored -> new ArrayList<>()).add(value);
            }
        }
        return tags;
    }

    private void writeReport(Path output) throws IOException {
        List<String> report = new ArrayList<>();
        report.add((errors.isEmpty() ? "PASS" : "FAIL") + ": packages=" + packages.size() + "; named types=" + types);
        report.addAll(errors);
        Files.write(output.resolve("qa/javadoc-structure.txt"), report, StandardCharsets.UTF_8);
        report.forEach(System.out::println);
    }

    private void generate(Path root, Path output) throws IOException {
        List<Path> sources;
        try (var files = Files.walk(root.resolve("src/main/java"))) {
            sources = files.filter(path -> path.toString().endsWith(".java")).sorted().toList();
        }
        String classpath = Files.readString(output.resolve("build/javadoc-classpath.txt")).strip();
        StringWriter messages = new StringWriter();
        var tool = ToolProvider.getSystemDocumentationTool();
        boolean success;
        try (var manager = tool.getStandardFileManager(null, null, StandardCharsets.UTF_8)) {
            var files = manager.getJavaFileObjectsFromPaths(sources);
            List<String> options = List.of("-quiet", "-encoding", "UTF-8", "-charset", "UTF-8", "-docencoding", "UTF-8",
                    "-Xdoclint:all,-missing", "-tag", "history:a:History:", "-classpath", classpath,
                    "-d", output.resolve("qa/javadoc").toString());
            success = tool.getTask(messages, manager, null, null, options, files).call();
        }
        Files.writeString(output.resolve("qa/javadoc-generation.log"), messages.toString(), StandardCharsets.UTF_8);
        if (!success) throw new IllegalStateException("Javadoc generation failed; see javadoc-generation.log");
        System.out.println("PASS: Javadoc generated with @history support");
    }
}
