# TASK-00.01.03 — Execution Context: QA

Resultado técnico: **pass**.
Fecha: 17 de noviembre de 2026, Europe/Madrid.
Proyecto: `software/iasi-setup-dev`, las mismas fuentes mantenidas en `src/`.

## Candidato y trazabilidad

Artefacto: `outputs/TASK-00.01.03/artifacts/iasi-setup-dev-0.1.0.jar`.
SHA-256: `4ad95a37782462157ea0207357421e291bad75022c3d00523f507f356327fb07`.
Main: org.iasi.setupdev.Main; bytecode Java 25 (major 69).
Dos builds limpios producen el mismo SHA-256.

Se aplica la tarea TASK-00.01.03-Context.iasi con COR-ARC-CTX-001 0.1.1 y
COR-MSG-RC-001 0.1.5. El usuario confirmó que la dependencia del enunciado se
refiere a TASK-0002. La nueva nomenclatura de tareas no altera IDs históricos,
versiones del producto ni documentos de tareas. Esta implementación sustituye
el diseño anterior de RC por el contrato nuevo, sin modificar especificaciones.

## Evidencias ejecutadas

| Control | Resultado | Evidencia relativa a la tarea |
| --- | --- | --- |
| Build y empaquetado | PASS | qa/logs/build.log |
| Reproducibilidad | PASS | qa/logs/reproducibility.log, qa/candidate.sha256 |
| Pruebas automatizadas | 112 ejecutadas, 0 fallos, 0 errores, 0 omitidas | qa/test-results/ |
| Procesos del JAR y capas de configuración | 16 casos PASS | qa/smoke-results.json |
| RC y salida real del proceso | 15 casos PASS | qa/rc-process-results.json |
| Publicación y fallos de contexto | 5 casos PASS | qa/context-process-results.json |
| Funciones documentadas | 194 declaraciones con Javadoc | qa/method-documentation.txt |
| Longitud efectiva | 31 / máximo 60 | qa/metrics.csv |
| Anidamiento | 3 / máximo 3 | qa/metrics.csv |
| Ciclomática | 9 / máximo 10 | qa/metrics.csv |
| Cognitiva | 11 / máximo 15 | qa/metrics.csv |
| Fuentes UTF-8 sin BOM, LF | PASS | qa/result.json |
| Inventario efectivo | 144 coordenadas/versión, sin cambios | qa/plugin-realms.txt, qa/dependency-tree.txt |
| OSV | 0 hallazgos para el inventario consultado | qa/security/osv-results.json |
| TASK-0001 preservada | PASS, comparación de hashes | qa/task-0001-preserved.json |
| TASK-0002 preservada | PASS, comparación de hashes | qa/task-0002-preserved.json |
| Especificaciones y release | Sin cambios durante el gate | qa/result.json |

Gate ejecutado: `python outputs/TASK-00.01.03/qa/tools/verify.py`, desde la raíz
del proyecto. Salida: qa/logs/core-refactor-gate.log. SourceGate 1.1.0 analiza
225 métodos/constructores/lambdas, incluidas pruebas y su propio código.
Las herramientas reales son Oracle JDK/javac 25.0.5.0.3 y Maven 3.10.1, registradas
en qa/toolchain-*.txt. El formatter fijado es 2.24.1 con Eclipse JDT 3.37.0.
No se han concedido excepciones a los límites obligatorios.

## Diseño de ctx

Context se implementa en org.iasisetupdev.core. Su única instancia se
crea mediante initialize después de resolver y validar la configuración.
Constructor privado, clase final, publicación con monitor de clase y rechazo de
una segunda inicialización garantizan identidad estable en la aplicación
ordinaria. getInstance antes de inicializar lanza IllegalStateException; no crea
una instancia perezosa con opciones parciales. Un fallo del constructor deja la
referencia sin publicar.

El contexto conserva solo configuración efectiva, UUID, instante inicial y RC.
ExecutionConfiguration es un record final de valores: cuatro Path normalizados,
Verbosity y force. Path y enum son valores inmutables; no se guardan Maps,
colecciones de negocio, objetos de consultas o setters de configuración. La
identidad, configuración e instante son final y se publican una vez.

Verbosity pasa a org.iasi.base como valor de configuración. La decisión de
visibilidad por Severity permanece en ConsoleSink, evitando una dependencia
base -> common. Se retira Settings y se usa la instantánea específica de la aplicación.
Los servicios de logging mantienen un ciclo de vida local, cerrado por el
coordinador. Context y ExecutionConfiguration pertenecen a la aplicación:
base conserva los valores reutilizables y common no conoce este contexto
concreto. Futuras referencias a servicios comunes podrán incorporarse al contexto
cuando exista una necesidad transversal justificada.

La única mutación propia del contexto es su entero rc. setRC y getRC usan el
monitor de la instancia, con actualización OR nativa y visibilidad entre hilos.
La protección de publicación y la de RC son las únicas sincronizaciones nuevas
del producto. No se introducen workers, atomics, colas o lambdas para acumular RC.
No hay reset ni varias ejecuciones independientes dentro de la misma JVM.

El test de ciclo de vida comprueba acceso antes de bootstrap, inicialización nula
sin publicación, ocho inicializadores concurrentes que observan el mismo objeto
completo, rechazo de reemplazo, estabilidad de identidad y configuración, y dos
escritores que actualizan Info/Warning 10000 veces cada uno sin perder bits.
La concurrencia se introduce solo en QA para acreditar el contrato exigido.
También se verifica que los dos accesos RC están sincronizados.

## RC y control de flujo

Se eliminan ReturnCode (enum), ReturnStatus y ReturnAccumulator del software
activo. RC declara exactamente ocho public static final int con sus valores
hexadecimales. OperationResult.status es un int, no una instancia de enum ni una
máscara envuelta. Se prueban los valores mediante reflexión y se recorren todas
las máscaras 0..0x7F para contrastar clasificación. 0x80 y Skip no se definen.

setRC realiza únicamente `rc |= value`: no sustituye, normaliza, valida, invoca
callbacks, lanza excepciones ni introduce saltos de control. Su precondición es
recibir una máscara IASI válida. La validación de máscaras externas al contexto
se realiza en fronteras de entrada, como el constructor de OperationResult,
mediante RC.isValid. Los códigos nativos de terceros requieren mapeo explícito;
no se añade una conversión automática.

El test demuestra Info|Warning=0x06, OK sin borrar bits, idempotencia de Warning y
continuación del código después de registrar Fatal. Registrar después Error
conserva la combinación 0x56. Los getters no modifican el resultado. Las
severidades de mensajes y su filtrado siguen siendo independientes del RC.

Main publica ctx después del bootstrap y pasa esa referencia a las operaciones
que necesitan configuración y RC. Los resultados hijos se incorporan con
ctx.setRC(result.status()). Las decisiones funcionales de ausencia de datos,
acción no disponible u host desconocido conservan su diagnóstico y agregan bits
sin atribuir saltos a setRC.

Ayuda y errores previos a la validación no publican ctx. El RC local de bootstrap
se utiliza únicamente cuando todavía no existe contexto operativo. Después de
publicar, el acumulado operativo único reside en ctx. Main cierra servicios con
try-with-resources y solo realiza una llamada final a System.exit(rc).

Los fallos controlados agregan Error. Un fallo RuntimeException inesperado agrega
Fatal conservando circunstancias anteriores. Se añade al catálogo existente el
evento SYS01010, severidad ERROR, con traducciones compatibles y diagnóstico
saneado; no se crea otro catálogo ni se expone la excepción cruda.

Los cinco procesos específicos verifican ayuda sin publicación/archivos,
configuración ausente sin contexto parcial, ejecución ordinaria publicada con
RC=0, Info|Warning=6 y una operación que registra Info antes de fallar. Esta
última cierra sus recursos, emite SYS01010 sin filtrar el secreto sintético y
termina con ctx.getRC()=exit status=0x42 (66). No se pierde el Info inicial ni se
hace System.exit dentro de la operación.

## Regresiones y aislamiento de pruebas

Las funcionalidades de CLI, flags secuenciales/agrupados, precedencia de valores,
rutas, force=false hardcoded, ayuda contextual, catálogos, log y detección del
host conservan sus casos de regresión. Los RC no cambian por consola silenciosa,
idioma, mensajes de progreso o DEBUG/TRACE. El pipeline devuelve los valores
acumulados 0, 1, 2, 4, 8, 16, 32, 64, 6, 12, 20, 18 y 127 sin reinterpretación.

Las invocaciones del launcher antes realizadas repetidamente en el mismo proceso
se ejecutan ahora en JVMs independientes. No se utiliza reflexión para vaciar
campos privados, reset, classloaders alternativos ni mocks que sustituyan el
Singleton. El harness se encuentra exclusivamente en fuentes de pruebas y en
una variante intermedia bajo build/. Se comprueba que no entra al JAR candidato.

El total cambia respecto a TASK-0002 porque se retiran pruebas exclusivas de los
tipos RC eliminados y se sustituyen por constantes y ciclo de vida del contexto;
las regresiones funcionales se conservan. El test de contexto mantiene una sola
vida real de Singleton por su JVM de pruebas, sin restaurar el estado entre fases.

## Estructura, alcance y seguridad

Las fuentes evolucionan en src/ del mismo proyecto. Maven dirige clases e
intermedios a outputs/TASK-00.01.03/build/target, el único candidato a artifacts/
y las evidencias a qa/. El gate conserva manifiestos completos por hash de las
dos entregas anteriores y comprueba que ninguna cambia. No hay target en raíces
ni iasi/outputs; ninguna evidencia o variante de QA se incluye en el producto.
Los logs/XML generados pueden conservar finales nativos como evidencia; las
fuentes y configuración propias se verifican en UTF-8 sin BOM y LF.

No hay dependencias externas nuevas. La consulta final OSV es
`2026-11-17T20:14:51.058584+00:00` mediante [OSV querybatch](https://api.osv.dev/v1/querybatch).
Se conserva la respuesta completa. Cero avisos se refiere a esas versiones y
consulta; no demuestra ausencia de vulnerabilidades desconocidas ni certifica
el SO/JDK/Maven del host. La ejecución física es Windows; las otras familias se
verifican con propiedades inyectadas.

No se modifican tareas, normas ni sus metadatos. Se conserva la aclaración del
usuario sobre la dependencia histórica y la nueva nomenclatura. No se renumeran
las tareas anteriores ni se promociona ningún artefacto a release.


## Corrección de ubicación solicitada por el usuario

El contexto es específico de cada aplicación. Por instrucción posterior del
usuario, la clase concreta es `org.iasisetupdev.core.Context` y su configuración
inmutable es `org.iasisetupdev.core.ExecutionConfiguration`. Se trasladan también
las pruebas de ciclo de vida a ese paquete. No queda una copia ni un alias en
org.iasi.base.context, y el JAR se inspecciona para exigir la clase nueva y la
ausencia de las antiguas. Las bibliotecas base/common no importan el core de la
aplicación; los tests de fronteras incluyen ambos namespaces de aplicación.

Se conserva la creación única al inicio operativo, después del bootstrap válido,
la publicación segura, la identidad estable, la acumulación OR sincronizada y la
ausencia de reset. La ayuda continúa sin publicar un contexto operativo.
Esta decisión específica prevalece sobre el nombre/paquete propuestos en los
documentos anteriores, que no se modifican.

El gate archiva los resultados previos de Surefire bajo qa/test-results-history
antes de ejecutar una nueva verificación. Así el cambio de nombre del test no
duplica un XML antiguo en los totales. Los 112 casos corresponden exclusivamente
a las clases actuales, con los 36 escenarios de proceso adicionales superados.
