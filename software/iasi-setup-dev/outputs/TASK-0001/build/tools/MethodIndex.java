import java.nio.file.*;
import java.util.*;
import javax.tools.*;
import com.sun.source.tree.*;
import com.sun.source.util.*;
class MethodIndex {
 public static void main(String[] args) throws Exception {
  Path root=Path.of(args[0]); List<Path> files=new ArrayList<>();
  try(var paths=Files.walk(root.resolve("src"))) { files.addAll(paths.filter(p->p.toString().endsWith(".java")).toList()); }
  files.add(root.resolve("qa/tools/SourceGate.java"));
  var compiler=ToolProvider.getSystemJavaCompiler();
  try(var fm=compiler.getStandardFileManager(null,null,null)) {
   JavacTask task=(JavacTask)compiler.getTask(null,fm,null,List.of("-proc:none"),null,fm.getJavaFileObjectsFromPaths(files));
   var units=task.parse(); Trees trees=Trees.instance(task); DocTrees docs=DocTrees.instance(task);
   for(var unit:units) new TreePathScanner<Void,Void>() {
    public Void visitMethod(MethodTree method,Void unused) {
     if(docs.getDocCommentTree(getCurrentPath())==null) {
      long begin=trees.getSourcePositions().getStartPosition(unit,method);
      System.out.println(Path.of(unit.getSourceFile().toUri())+"\t"+begin+"\t"+method.getName());
     }
     return super.visitMethod(method,unused);
    }
   }.scan(unit,null);
  }
 }
}