# TASK-00.01.04 — Incremento 01: QA

Verificación técnica del incremento: **pass**. Tarea interactiva abierta.
Fecha: 17 de noviembre de 2026, Europe/Madrid.
Baseline: `a94209d3519663623dc60ab11df6f2c4f4e6aa59`.

Candidato: artifacts/iasi-setup-dev-0.1.0.jar.
SHA-256: `d5a3fb18c501c4638e9487835f2836d59e738d2b59c4a6afdcbc431a475650dd`.
Se han ejecutado dos builds limpios con el mismo SHA-256. Las fuentes siguen en
src/ del mismo proyecto; solo los productos generados se aíslan por tarea.

| Control | Resultado | Evidencia relativa a la tarea |
| --- | --- | --- |
| Compilación, pruebas y formato | 113 pruebas; 0 fallos, 0 errores y 0 omitidas | qa/logs/build.log, qa/test-results/ |
| JAR y configuración | 16 casos PASS | qa/smoke-results.json |
| RC y salida real | 15 casos PASS | qa/rc-process-results.json |
| Contexto, ayuda y fallo inesperado | 5 casos PASS | qa/context-process-results.json |
| Build reproducible | PASS | qa/logs/reproducibility.log, qa/candidate.sha256 |
| Funciones documentadas | 202 declaraciones con Javadoc | qa/method-documentation.txt |
| Longitud efectiva | 23 / 60 | qa/metrics.csv |
| Anidamiento | 3 / 3 | qa/metrics.csv |
| Ciclomática | 9 / 10 | qa/metrics.csv |
| Cognitiva | 10 / 15 | qa/metrics.csv |
| UTF-8 sin BOM y LF | PASS | qa/result.json |
| Inventario efectivo y OSV | 144 coordenadas sin cambio; 0 hallazgos en la consulta | qa/security/osv-results.json |
| Entregas anteriores | TASK-0001, TASK-0002 y TASK-00.01.03 sin cambios | qa/task-*-preserved.json |
| Normas y release | Sin cambios durante el gate | qa/result.json |

Comando: python outputs/TASK-00.01.04/qa/tools/verify.py, desde la raíz del
proyecto. Salida: qa/logs/increment-01-gate.log. No se introducen dependencias.
Cero avisos OSV se refiere al inventario y consulta guardados, sin afirmar ausencia
de vulnerabilidades desconocidas. Las pruebas físicas se realizan en Windows.

Se revisó Main, el traslado de coordinación a App, los accesos de consola del
contexto y las adaptaciones mínimas de pruebas. Se preservan configuración por
capas, flags secuenciales, force, mensajes, RC OR y diagnóstico de plataforma.
Help continúa siendo un componente propio sin funciones de ayuda en Main.

Main contiene solamente main y el constructor público implícito de Java. Su
cuerpo crea App, ejecuta run y lee el RC del Singleton para la salida final. App
no tiene estado RC alternativo. Los fallos operativos se acumulan en ctx y los
recursos de logging se cierran antes de que Main termine el proceso.

Initialize no ejecuta el diagnóstico ni abre logs; analiza y valida antes de
publicar ctx. Ayuda y errores previos al contexto conservan salida anticipada
sin archivos o directorios operativos. Los streams se preparan en bootstrap y se
publican como referencias estables de ctx al crearlo; durante la operación se
utilizan ctx.out/err y nunca se declaran streams en Main.

El harness de pruebas incorpora un hook de cierre exclusivo de QA para observar
los System.exit reales de bootstrap. No se añade ningún worker al producto. La
variante de prueba permanece bajo build/; no entra en artifacts. La inspección
arquitectónica limita System.exit al final de Main y al bootstrap de App.

El cambio de la política de terminación anticipada ha sido acordado expresamente
con el usuario. Se documenta la ayuda como ruta previa al contexto para conservar
su contrato observable. No se alteran los valores RC ni la separación entre
severidad y resultado. El caso Info seguido de fallo sigue devolviendo 0x42.

El registro de decisiones y archivos está en change-log.md. No se han revisado
ni reorganizado las responsabilidades restantes de initialize: serán nuevos
incrementos discutidos con el desarrollador. Este pass verifica el incremento;
no supone aceptación de incrementos futuros ni finalización de toda la tarea.
