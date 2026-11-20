import com.sun.source.tree.BlockTree;
import com.sun.source.tree.CaseTree;
import com.sun.source.tree.ClassTree;
import com.sun.source.tree.CompilationUnitTree;
import com.sun.source.tree.IfTree;
import com.sun.source.tree.LambdaExpressionTree;
import com.sun.source.tree.MethodTree;
import com.sun.source.tree.Tree;
import com.sun.source.util.JavacTask;
import com.sun.source.util.DocTrees;
import com.sun.source.util.TreePathScanner;
import com.sun.source.util.TreeScanner;
import com.sun.source.util.Trees;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;
import java.util.Set;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import javax.tools.Diagnostic;
import javax.tools.DiagnosticCollector;
import javax.tools.JavaFileObject;
import javax.tools.ToolProvider;

/**
 * Checks source encoding, style and callable complexity while treating method documentation as optional.
 *
 * @author Javier G. Grandez
 * @since 0.1.0
 * @version 0.1.0
 * @history 2026-11-19 | 0.1.0 | Establish structural documentation and component responsibilities.
 */
class SourceGate {
    private static final List<String> ERRORS = new ArrayList<>();
    private static final List<String> SCORES = new ArrayList<>();
    private static int documentedMethods;
    private static final Pattern LEXEMES = Pattern
            .compile("\"\"\"[\\s\\S]*?\"\"\"|\"(?:\\\\.|[^\"\\\\])*\"|'(?:\\\\.|[^'\\\\])*'|/\\*[\\s\\S]*?\\*/|//[^\\r\\n]*");

    public static void main(String[] arguments) throws Exception {
        if (Runtime.version().feature() != 25) throw new IllegalStateException("JDK 25 required");
        Path root = Path.of(arguments[0]);
        Path output = arguments.length > 1 ? Path.of(arguments[1]) : root;
        List<Path> paths;
        try (var files = Files.walk(root.resolve("src"))) {
            paths = new ArrayList<>(files.filter(Files::isRegularFile).sorted().toList());
        }
        paths.add(output.resolve("qa/tools/SourceGate.java"));
        for (Path path : paths)
            inspectBytes(path);
        analyze(paths.stream().filter(path -> path.toString().endsWith(".java")).toList());
        Files.createDirectories(output.resolve("qa"));
        Files.write(output.resolve("qa/metrics.csv"), SCORES, StandardCharsets.UTF_8);
        for (String error : ERRORS)
            System.err.println(error);
        if (!ERRORS.isEmpty()) throw new IllegalStateException("Source QA failed: " + ERRORS.size());
        Files.writeString(output.resolve("qa/method-documentation.txt"), "INFO: optional method/constructor Javadoc count=" + documentedMethods + "\n");
        System.out.println("IASI SourceGate 1.1.0 PASS; scored callables=" + (SCORES.size() - 1) + "; documented methods=" + documentedMethods);
    }

    private static void inspectBytes(Path path) throws IOException {
        String text = StandardCharsets.UTF_8.newDecoder().decode(java.nio.ByteBuffer.wrap(Files.readAllBytes(path))).toString();
        if (text.startsWith("\ufeff")) ERRORS.add(path + ": BOM");
        if (text.contains("\r")) ERRORS.add(path + ": expected LF");
        if (!text.endsWith("\n")) ERRORS.add(path + ": missing final newline");
        if (text.contains("\t")) ERRORS.add(path + ": tabs");
        for (String line : text.split("\n")) {
            if (!line.equals(line.stripTrailing())) ERRORS.add(path + ": trailing whitespace");
        }
    }

    private static void analyze(List<Path> sources) throws IOException {
        var compiler = ToolProvider.getSystemJavaCompiler();
        var diagnostics = new DiagnosticCollector<JavaFileObject>();
        SCORES.add("file,callable,line,effectiveLines,nesting,cyclomatic,cognitive");
        try (var manager = compiler.getStandardFileManager(diagnostics, null, StandardCharsets.UTF_8)) {
            var files = manager.getJavaFileObjectsFromPaths(sources);
            JavacTask task = (JavacTask) compiler.getTask(null, manager, diagnostics, List.of("-proc:none", "--release", "25"), null, files);
            var units = task.parse();
            Trees trees = Trees.instance(task);
            DocTrees documentation = DocTrees.instance(task);
            for (CompilationUnitTree unit : units)
                inspectUnit(unit, trees, documentation);
        }
        for (var diagnostic : diagnostics.getDiagnostics()) {
            if (diagnostic.getKind() == Diagnostic.Kind.ERROR) ERRORS.add(diagnostic.toString());
        }
    }

    private static void inspectUnit(CompilationUnitTree unit, Trees trees, DocTrees documentation) throws IOException {
        Source source = new Source(unit, trees, unit.getSourceFile().getCharContent(true).toString());
        new TreePathScanner<Void, Void>() {

            @Override
            public Void visitMethod(MethodTree method, Void unused) {
                boolean ownedSource = unit.getPackageName() != null || unit.getSourceFile().getName().endsWith("SourceGate.java");
                if (ownedSource) inspectDocumentation(documentation, getCurrentPath(), method.getName().toString());
                if (method.getBody() != null) inspectMethod(source, method);
                return super.visitMethod(method, unused);
            }

            @Override
            public Void visitLambdaExpression(LambdaExpressionTree lambda, Void unused) {
                inspectCallable(source, lambda, lambda.getBody(), "<lambda>", 0);
                return super.visitLambdaExpression(lambda, unused);
            }

            @Override
            public Void visitIf(IfTree conditional, Void unused) {
                inspectBranch(source, conditional, conditional.getThenStatement());
                if (conditional.getElseStatement() != null) inspectBranch(source, conditional, conditional.getElseStatement());
                return super.visitIf(conditional, unused);
            }
        }.scan(unit, null);
    }

    private static void inspectMethod(Source source, MethodTree method) {
        long begin = source.begin(method);
        var annotations = method.getModifiers().getAnnotations();
        if (!annotations.isEmpty()) begin = source.end(annotations.getLast());
        String text = source.text().substring((int) begin, (int) source.end(method)).strip();
        inspectCallable(source, method, method.getBody(), method.getName().toString(), effectiveLines(text));
    }

    private static void inspectDocumentation(DocTrees documentation, com.sun.source.util.TreePath path, String method) {
        if (documentation.getDocCommentTree(path) != null) documentedMethods++;
    }

    private static int effectiveLines(String source) {
        String clean = LEXEMES.matcher(source).replaceAll(match -> {
            String token = match.group();
            if (token.startsWith("/")) return Matcher.quoteReplacement(token.replaceAll("[^\\r\\n]", " "));
            return Matcher.quoteReplacement(token);
        });
        return (int) clean.lines().filter(line -> !line.isBlank()).count();
    }

    private static void inspectCallable(Source source, Tree declaration, Tree body, String name, int lines) {
        Metrics metrics = new Metrics();
        metrics.scan(body, null);
        String id = Path.of(source.unit().getSourceFile().toUri()).getFileName() + "," + name + "," + source.line(source.begin(declaration));
        SCORES.add(id + "," + lines + "," + metrics.maximum + "," + metrics.cyclomatic + "," + metrics.cognitive);
        if (lines > 60) ERRORS.add(id + ": length exceeds 60");
        if (metrics.maximum > 3) ERRORS.add(id + ": nesting exceeds 3");
        if (metrics.cyclomatic > 10) ERRORS.add(id + ": cyclomatic exceeds 10");
        if (metrics.cognitive > 15) ERRORS.add(id + ": cognitive exceeds 15");
    }

    private static void inspectBranch(Source source, IfTree conditional, Tree branch) {
        String id = source.unit().getSourceFile().getName() + ":" + source.line(source.begin(branch));
        if (branch instanceof BlockTree block) {
            if (block.getStatements().size() == 1) ERRORS.add(id + ": single branch has braces");
            return;
        }
        if (branch instanceof IfTree) return;
        if (!source.sameLine(source.begin(branch), source.end(branch))) ERRORS.add(id + ": single branch spans lines");
        boolean thenBranch = branch == conditional.getThenStatement();
        if (thenBranch && !source.sameLine(source.end(conditional.getCondition()), source.begin(branch))) ERRORS.add(id + ": if must be one line");
    }

    /**
     * Relates parsed Java trees to their original source positions for metric calculations.
     *
     * @author Javier G. Grandez
     * @since 0.1.0
     * @version 0.1.0
     * @history 2026-11-19 | 0.1.0 | Establish structural documentation and component responsibilities.
     */
    private record Source(CompilationUnitTree unit, Trees trees, String text) {

        long begin(Tree tree) {
            return trees.getSourcePositions().getStartPosition(unit, tree);
        }

        long end(Tree tree) {
            return trees.getSourcePositions().getEndPosition(unit, tree);
        }

        long line(long position) {
            return unit.getLineMap().getLineNumber(position);
        }

        boolean sameLine(long first, long second) {
            return line(first) == line(second);
        }
    }

    /**
     * Counts control-flow complexity and nesting within an inspected callable.
     *
     * @author Javier G. Grandez
     * @since 0.1.0
     * @version 0.1.0
     * @history 2026-11-19 | 0.1.0 | Establish structural documentation and component responsibilities.
     */
    private static final class Metrics extends TreeScanner<Void, Void> {
        private static final Set<Tree.Kind> STRUCTURES = Set.of(Tree.Kind.FOR_LOOP, Tree.Kind.ENHANCED_FOR_LOOP, Tree.Kind.WHILE_LOOP, Tree.Kind.DO_WHILE_LOOP,
                Tree.Kind.CATCH, Tree.Kind.SWITCH, Tree.Kind.SWITCH_EXPRESSION, Tree.Kind.CONDITIONAL_EXPRESSION);
        private int depth;
        private int maximum;
        private int cyclomatic = 1;
        private int cognitive;

        @Override
        public Void scan(Tree tree, Void unused) {
            if (tree == null) return null;
            if (tree instanceof IfTree conditional) return conditional(conditional);
            Tree.Kind kind = tree.getKind();
            boolean structure = STRUCTURES.contains(kind);
            if (structure) enterStructure(kind);
            if (kind == Tree.Kind.CONDITIONAL_AND || kind == Tree.Kind.CONDITIONAL_OR) {
                cyclomatic++;
                cognitive++;
            }
            if (tree instanceof CaseTree branch && !branch.getExpressions().isEmpty()) cyclomatic++;
            Void result = super.scan(tree, unused);
            if (structure) depth--;
            return result;
        }

        private void enterStructure(Tree.Kind kind) {
            cognitive += depth + 1;
            depth++;
            maximum = Math.max(maximum, depth);
            if (kind != Tree.Kind.SWITCH && kind != Tree.Kind.SWITCH_EXPRESSION) cyclomatic++;
        }

        private Void conditional(IfTree conditional) {
            cyclomatic++;
            cognitive += depth + 1;
            depth++;
            maximum = Math.max(maximum, depth);
            scan(conditional.getCondition(), null);
            scan(conditional.getThenStatement(), null);
            depth--;
            if (conditional.getElseStatement() != null) alternative(conditional.getElseStatement());
            return null;
        }

        private void alternative(Tree alternative) {
            cognitive++;
            boolean block = alternative instanceof BlockTree;
            if (block) depth++;
            maximum = Math.max(maximum, depth);
            scan(alternative, null);
            if (block) depth--;
        }

        @Override
        public Void visitLambdaExpression(LambdaExpressionTree lambda, Void unused) {
            return null;
        }

        @Override
        public Void visitClass(ClassTree type, Void unused) {
            return null;
        }
    }
}
