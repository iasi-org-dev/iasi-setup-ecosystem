# TASK-00.01.04 — Cambios por incremento

## 01 — Main mínimo y coordinación por instancia App

Baseline Git: `a94209d3519663623dc60ab11df6f2c4f4e6aa59`. El documento de ejemplos tenía modificaciones del
usuario al empezar; no se ha editado. El commit fija un punto recuperable, no una
aprobación QA. No se ha creado un commit de este incremento.

Acuerdo de la conversación: Main sin constructor privado, creación de App como
instancia, App.run(args), salida normal leyendo RC directamente de ctx. Out y
err pertenecen al contexto; ayuda conserva su componente propio. Initialize
analiza y crea el contexto; el error de análisis impide continuar el proceso.

| Archivos | Cambio y motivo |
| --- | --- |
| src/main/java/org/iasi/setupdev/Main.java | Solo main con las tres instrucciones acordadas |
| src/main/java/org/iasi/setupdev/App.java | Instancia con run e initialize; coordinación retirada de Main |
| src/main/java/org/iasisetupdev/core/Context.java | Out/err como referencias finales; acceso y propiedad documentados |
| src/test/java/org/iasi/setupdev/ReturnCodeProcessMain.java | Harness usa App real y observa salidas anticipadas con hook exclusivo de QA |
| src/test/java/org/iasi/setupdev/DependencyDirectionTest.java | Verifica Main mínimo y excepciones de salida en los límites de aplicación |
| src/test/java/org/iasisetupdev/core/ContextTest.java | Comprueba las referencias estables de streams |
| pom.xml y helpers QA | Resultados aislados por TASK-00.01.04 y preservación de entregas anteriores |

Se conserva la inicialización de Context de un argumento y se añade la variante
con streams para mantener compatibilidad. El constructor inyectable de App
reutiliza los colaboradores del antiguo pipeline para las pruebas. No se añaden
contenedores artificiales de parámetros ni se redefine el RC.

La ayuda exclusiva termina en bootstrap con OK sin crear contexto, como antes.
Los errores de parser siguen identificándose con InputException; App.initialize
emite el diagnóstico y termina con el RC apropiado. El parser de bajo nivel no
se convierte en un terminador de JVM reutilizable. La salida anticipada del
bootstrap se concentra en un método de App; el flujo normal tiene su única
salida final en Main. Las bibliotecas siguen sin System.exit.

Pruebas: 113 sin fallos y 36 casos de proceso. Gate completo,
formato, métricas y reproducibilidad: pass. La evidencia detallada figura en
qa/qa-report.md y qa/logs/increment-01-gate.log.

Pendiente de discusión: siguientes responsabilidades y descomposición de
initialize. No se declara terminada la tarea interactiva.
