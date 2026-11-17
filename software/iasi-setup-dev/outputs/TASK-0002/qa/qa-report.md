# TASK-0002 — Application Return Codes: QA

Resultado: **pass, verificación técnica del candidato**.
Fecha: 17 de noviembre de 2026, Europe/Madrid.
Baseline de partida: commit del usuario `c5d065e` (TASK001).
Proyecto: `software/iasi-setup-dev` dentro del contenedor multiproyecto.

## Resultado y artefacto

- Fuentes y pruebas: `src/` del proyecto; configuración Maven: `pom.xml`.
- Candidato: `outputs/TASK-0002/artifacts/iasi-setup-dev-0.1.0.jar`.
- SHA-256: `f57dc374c9fe6a0b8ef3ae917ebac89722cf42abf611d39ca7ab59d02f2ade34`.
- Main del producto: `org.iasi.setupdev.Main`, bytecode Java 25 (major 69).
- Dos compilaciones limpias consecutivas generan el mismo candidato.
- TASK-0001, las especificaciones y los árboles release permanecen intactos.

## Controles ejecutados

| Control | Resultado | Evidencia relativa a TASK-0002 |
| --- | --- | --- |
| Compilación y empaquetado | PASS | `qa/logs/build.log` |
| Build reproducible | PASS, mismo SHA-256 | `qa/logs/reproducibility.log`, `qa/candidate.sha256` |
| Pruebas automatizadas | 115 ejecutadas, 0 fallos, 0 errores, 0 omitidas | `qa/test-results/` |
| Casos heredados del JAR | 16 PASS | `qa/smoke-results.json` |
| Casos adicionales de RC en proceso | 15 PASS | `qa/rc-process-results.json` |
| Formato y documentación | PASS; Javadoc en 184 declaraciones | `qa/logs/build.log`, `qa/method-documentation.txt` |
| Longitud efectiva | Máximo 23 / 60 | `qa/metrics.csv` |
| Anidamiento | Máximo 3 / 3 | `qa/metrics.csv` |
| Ciclomática | Máximo 9 / 10 | `qa/metrics.csv` |
| Cognitiva | Máximo 9 / 15 | `qa/metrics.csv` |
| UTF-8 sin BOM y LF | PASS | `qa/result.json` |
| Dependencias efectivas | 144, baseline sin cambios | `qa/plugin-realms.txt`, `qa/dependency-tree.txt` |
| Consulta OSV | 0 hallazgos para ese inventario | `qa/security/osv-results.json` |
| TASK-0001 preservada | PASS, comparación completa por hashes | `qa/task-0001-preserved.json` |
| iasi y release | Sin cambios | `qa/result.json`, comprobación git final |
| Separación OUT-001/OUT-002 | PASS | build/target, artifacts y qa independientes |

Último gate completo: `python outputs/TASK-0002/qa/tools/verify.py`, desde la raíz
del proyecto. Salida: `qa/logs/full-gate.log`. Las métricas de SourceGate 1.1.0
incluyen 217 callables, con producción, pruebas y el propio checker.
Oracle JDK/javac 25.0.5.0.3 y Maven 3.10.1 son las herramientas ejecutadas;
sus salidas se conservan en `qa/toolchain-*.txt`.

## Implementación del contrato RC

`org.iasi.base.ReturnCode` contiene exactamente los ocho indicadores aprobados:
OK=0x00, NOTHING_TO_DO=0x01, INFO=0x02, WARNING=0x04, ATTENTION=0x08, ERROR=0x10,
SEVERE=0x20 y FATAL=0x40. Los nombres Java respetan la convención de constantes;
la correspondencia con NothingToDo/Info/etc. del documento es uno a uno.

`ReturnStatus` es una máscara inmutable construida únicamente a partir de esos
indicadores u otras máscaras válidas. No hay fábrica o constructor público que
acepte enteros nativos. Combina mediante OR, conserva repeticiones e identidades
y clasifica el error con los bits 0x10/0x20/0x40. No asigna nombres a combinaciones,
ni implementa Skip, 0x80 o bits adicionales. Se recorren exhaustivamente las 128
máscaras representables para contrastar valor, clasificación y ausencia del bit
reservado.

`ReturnAccumulator` mantiene un RC por ejecución iniciado en OK. Devuelve
instantáneas inmutables y preserva circunstancias anteriores al incorporar hijos
o errores posteriores. No es Singleton, no es un servicio global y no controla
por sí mismo la continuación, cancelación o terminación ante Fatal.

`org.iasi.common.operation.OperationResult` separa los datos opcionales de su RC.
Platform.identify produce un resultado tipado; familias conocidas conservan OK y
familias desconocidas aportan Error. Ambas rutas se comprueban con propiedades
inyectadas y sin mutar propiedades globales del proceso. El launcher agrega el
resultado hijo y marca NothingToDo cuando no hay datos de trabajo aplicables.
Un error detectado después de Info conserva ambos indicadores (0x12).

La dirección de dependencias es descendente: base solo depende del JDK;
common utiliza base y no importa setupdev; setupdev consume common y los tipos
RC de base. Las pruebas de arquitectura verifican esas fronteras. La fachada de
logging y sus destinos siguen independientes del RC: ni las severidades, ni los
colores, ni la verbosidad, ni el idioma alteran la máscara.

Main conserva la coordinación existente y entrega el acumulado sin transformación
a System.exit. Solo el entry point del producto contiene esa llamada; no hay
terminación de JVM en base/common ni uso de Runtime.exit/halt. Las operaciones
internas devuelven resultados en vez de finalizar el proceso. No hay ejecución
de herramientas externas desde el producto; su futura integración necesitará un
mapeo explícito de códigos nativos a indicadores, no una conversión directa.

## Comportamiento y compatibilidad

Ayuda válida y diagnóstico ordinario conservan RC=0. Los mensajes START, PATHS,
PLATFORM, RUNTIME, VERIFIED y FINISH no activan Info por el hecho de emitirse.
Las pruebas comprueban ese comportamiento en modo detallado y silencioso.

CLI/configuración inválida, IO controlado, acción no implementada y host
desconocido devuelven Error=16. Este cambio sustituye intencionadamente los
antiguos códigos secuenciales 1/2/3; las expectativas de seis aserciones heredadas
se actualizan a la nueva máscara, conservando sus verificaciones funcionales y
su ausencia de efectos laterales. Los 77 casos de la entrega anterior pasan junto
con las nuevas verificaciones del estándar.

Una operación puede devolver Info por una circunstancia relevante o NothingToDo
por ausencia de trabajo; no se derivan de imprimir texto. En este bootstrap no se
añaden comandos operativos ni flags de prueba para fabricar esas circunstancias.
Se ejercita su propagación con operaciones inyectadas en el pipeline real, tanto
en pruebas en memoria como desde límites de procesos independientes.

Las integraciones JUnit lanzan un entry point exclusivo de QA en un proceso Java
y comprueban su exitValue real para todos los bits y varias combinaciones. El
gate adicional crea una variante temporal del JAR con ese entry point, ejecuta
las mismas operaciones y comprueba 0, 1, 2, 4, 8, 16, 32, 64, 6, 12, 20, 18,
una repetición de Info y 127, además del fallo de archivo externo sobre el JAR
real. Se comprueban los RC persistidos en FINISH y la ausencia de SUCCESS cuando
hay error o no hay trabajo.

Esa variante de QA está en build/ y no es el candidato. El JAR de artifacts no
contiene ReturnCodeProcessMain, JUnit, fuentes, informes QA ni defaults.toml de
una máquina. Los casos de ayuda, flags secuenciales/agrupados, configuración por
capas, rutas, localización, logs y detección del host siguen pasando en el gate.
Force continúa hardcoded a false y solo -f lo activa.

## Normas, estructura y discrepancias

Se aplica COR-MSG-RC-001 0.1.1 al alcance solicitado expresamente por TASK-0002.
El enunciado referencia `messages-return-codes.iasi`, pero el documento real está
en `iasi/specifications/corporate/runtime/corporate-return-codes.iasi`. Se localizó
por ID y versión. Se informa la discrepancia sin editar ninguno de los documentos
ni convertir su estado draft en una aprobación corporativa.

La tarea nueva pide fuentes y pruebas en la raíz del proyecto: `src/` y pom.xml.
Todos los productos generados y evidencias están en outputs/TASK-0002, de acuerdo
con CORP-WF-OUT-001/002. El gate comprueba ausencia de target en las raíces del
proyecto y del contenedor, ausencia de iasi/outputs, y separación de intermediarios,
candidato y QA. TASK-0001 se conserva como baseline histórico inmutable.

Se mantiene la normativa Java aplicable: nombres, cuatro espacios, if de una
instrucción en una línea sin llaves, composición funcional, Javadoc y máximos por
método. La configuración compartida y los criterios de SourceGate proceden de
TASK-0001; no cambian los umbrales ni se conceden excepciones. No se añaden nuevas
dependencias. El inventario efectivo se contrasta con la línea inicial heredada.

Consulta OSV final: `2026-11-17T18:27:30.242635+00:00`.
Fuente: [OSV querybatch](https://api.osv.dev/v1/querybatch).
Se conserva la respuesta completa. Cero avisos se refiere a las versiones
consultadas y no certifica ausencia de vulnerabilidades desconocidas ni el SO o
la instalación de Java/Maven del host. La ejecución física se limita a Windows;
las otras familias se prueban mediante propiedades inyectadas.

## Estado de workflow

La verificación técnica del candidato es pass. El documento de tarea conserva
`status = pending`: no se ha marcado approved, in progress o done, ni se han
modificado approver/date ni movido el archivo. No se ha localizado una
implementación del comando de aprobación acordado en las fuentes consultadas y
no se inventa una transición alternativa. La aprobación formal y la promoción
son independientes de esta implementación autorizada por el usuario.

No se modifican especificaciones, catálogos de mensajes ni procesos de aprobación.
No hay colas asíncronas, Singleton, parser universal, instalación, máquinas,
workflows operativos ni promoción a ninguno de los árboles release.
