# TASK-0001 — Informe QA

Resultado: **pass, verificación técnica del candidato**.
Fecha: 17 de noviembre de 2026, Europe/Madrid.
Proyecto: `J:/iasi-setup-ecosystem/software/iasi-setup-dev`.
Resultados: `outputs/TASK-0001/` de este proyecto.

La implementación se ha creado desde cero en la raíz corregida. El ecosistema
se trata como contenedor multiproyecto. No se han modificado especificaciones,
entradas externas originales ni el estado documental de TASK-0001. El código
se rige por las correcciones explícitas del usuario registradas en
`qa/contract-decisions.md`; estas prevalecen sobre los contratos antiguos.

## Candidato

- `artifacts/iasi-setup-dev-0.1.0.jar`, ejecutable y autónomo.
- SHA-256: `0e9ad35b56c10f1afa52eebb618e202e82564c97f9dc0bd63d03d0f436c776ea`.
- Java 25, bytecode major 69, main `org.iasi.setupdev.Main`.
- Dos compilaciones limpias consecutivas producen el mismo SHA-256.
- Contiene dependencias de ejecución, licencias y avisos. No contiene pruebas,
  fuentes, QA ni el defaults.toml de una máquina.
- No hay promoción a release; el pass técnico no constituye aprobación
  organizativa ni autorización para publicar.

## Controles ejecutados

| Control | Resultado | Evidencia |
| --- | --- | --- |
| Build limpio y JAR ejecutable | PASS | `qa/logs/build.log` |
| Reproducibilidad | PASS, mismo SHA-256 | `qa/logs/reproducibility.log`, `qa/candidate.sha256` |
| Pruebas automatizadas | 77 pruebas, 0 fallos, 0 errores, 0 omitidas | `qa/test-results/` |
| Procesos independientes del JAR | 16 casos PASS | `qa/smoke-results.json`, logs bajo `qa/smoke/` |
| Formato no mutante | PASS, cuatro espacios y reglas IASI | `qa/logs/build.log`, `qa/config/eclipse.xml` |
| UTF-8 sin BOM y LF | PASS sobre bytes de fuentes/configuración | `qa/result.json` |
| Longitud efectiva | Máximo 23 / 60 | `qa/metrics.csv` |
| Anidamiento | Máximo 3 / 3 | `qa/metrics.csv` |
| Ciclomática | Máximo 9 / 10 | `qa/metrics.csv` |
| Cognitiva | Máximo 8 / 15 | `qa/metrics.csv` |
| Inventario efectivo | 144 coordenadas/versión | `qa/plugin-realms.txt`, `qa/dependency-tree.txt` |
| OSV | 0 hallazgos en ese inventario | `qa/security/osv-results.json` |
| Separación OUT-001 / OUT-002 | PASS | `qa/result.json`, distribución descrita abajo |
| Gobierno y release | Sin cambios | Comparación de hashes antes/después en el gate |

El último comando ejecutado fue `python qa/tools/verify.py` sobre la versión
refactorizada. Su salida está en `qa/logs/refactor-gate.log`. Se conserva la
selección inicial de dependencias; el inventario efectivo no ha cambiado y el
gate no ha reescrito su baseline. `qa/logs/gate.log` corresponde a la entrega
inicial, anterior a esta refactorización.

## Contrato funcional comprobado

La resolución superpone solo claves presentes, en este orden: hardcoded,
recurso interno opcional del JAR, archivo externo seleccionado por --config y
CLI explícita. Sin capas opcionales, definitions/machines/logs resuelven al CWD
original y verbose es false. Se verifican rutas absolutas y relativas, las
combinaciones independientes de directorios, herencia de claves ausentes,
verbose=false externo sobre true interno y CLI sobre todas las capas.

`force=false` está hardcoded y no forma parte de las cuatro entradas TOML.
Solo -f lo activa para la instancia. Se rechazan force=true y force=false en
archivos; ambas variantes tienen prueba automatizada. También se comprueba que
los errores se detectan antes de crear logs o directorios parciales.

Los flags de verbosidad se aplican secuencialmente: -v -s -V y -vsV dejan -V;
-V -s y -Vs dejan -s. La CLI sobrescribe verbose del archivo. No se denuncia
incompatibilidad entre esos flags. Se prueban flags agrupados, mayúsculas,
valores separados, valores literales con aspecto de flag, rutas con espacios y
parámetros repetidos, para los que gana el último.

El archivo real de ejemplo `J:/iasi-setup-ecosystem/definitions/defaults.toml`
se conserva como snapshot de prueba en `qa/inputs/defaults.toml`, con sus cuatro
entradas actuales y sin force. No se modifica ni se introduce como recurso del
JAR. Las pruebas de proceso lo cargan mediante --config y sobrescriben --logs
para mantener los resultados dentro de la tarea.

El soporte de recurso interno se prueba tanto con InputStream inyectado como
con una variante temporal del JAR creada bajo build/. Esa variante contiene un
recurso TOML interno; el archivo externo lo sobrescribe y la CLI sobrescribe a
ambos. La variante es material intermedio de prueba y no es el candidato de
artifacts. La salida normal usa el JAR real sin archivo interno.

La ayuda general y contextual no carga archivos, no consulta el host, no crea
logs ni directorios, incluso con --config ausente y --logs explícito. Los
contextos create y workflow release solo ofrecen ayuda; su ejecución devuelve
error sin simular éxito ni consultar la plataforma.

La detección estructura familia, nombre, versión, arquitectura, runtime y vendor.
Windows, Linux/GNU, macOS/Darwin y sistemas desconocidos se prueban mediante
propiedades inyectadas, incluida arquitectura s390x. La ejecución física se ha
realizado en Windows 11 amd64. No se deducen capacidades de hipervisor.

La mensajería mantiene códigos LLLNNMMM estables e independientes del idioma,
catálogos español/inglés con fallback inglés, formato HH:mm:ss - código - texto,
severidades, colores y stderr para errores. Se verifican todos los modos de
consola, log independiente del filtro, TRACE solo con configuración explícita,
archivos distintos por ejecución y fallos de escritura. Se comprueban saneado de
secretos, credenciales de URI, controles e inyección de líneas antes de ambos
destinos. El ejecutable se captura con decodificación UTF-8 estricta y conserva
las etiquetas españolas, sin ANSI en salidas redirigidas ni logs.

## Herramientas y calidad

Oracle Java/javac 25.0.5.0.3 y Maven 3.10.1 fueron las herramientas reales;
sus salidas se guardan en `qa/toolchain-*.txt`. SourceGate exige JDK 25 y el
artefacto se inspecciona para comprobar bytecode 69. El formateador fijado es
formatter-maven-plugin 2.24.1 con Eclipse JDT 3.37.0. Tras clean, validate compara
las fuentes sin modificarlas. La configuración compartida conserva la convención
de if de una instrucción sin llaves y en la misma línea.

IASI SourceGate 1.1.0 analiza 166 métodos, constructores y lambdas,
incluidos producción, pruebas y el propio checker, mediante AST del compilador.
Las convenciones y limitaciones están documentadas en `qa/contract-decisions.md`.
No se afirma equivalencia de sus puntuaciones con Sonar. Las lambdas se evalúan
separadamente y tienen longitud 0 como no aplicable a métodos/constructores.
Hay pruebas del checker con métricas conocidas, comentarios, else-if y defectos
deliberados de longitud, profundidad, complejidad, BOM y formato. No se han
concedido excepciones a los máximos obligatorios.

Las versiones iniciales y overrides de herramientas están fijados en pom.xml;
la selección se explica en el documento de decisiones. TOMLJ valida el archivo
completo antes de usar valores, evitando un lector parcial que acepte TOML
corrupto. Es la única dependencia directa de ejecución; sus transitivas son
ANTLR y checker-qual. JUnit se limita a pruebas.

La revisión de seguridad usa el grafo de ejecución/pruebas y los class realms
realmente cargados por Maven, incluido el provider de Surefire y la herramienta
de inspección. No se toma el POM original de un plugin como prueba de que una
sustitución se haya aplicado. Solo se guardan coordenadas y salida normal de
Maven, sin su volcado completo de debug y propiedades.

Consulta OSV: `2026-11-17T17:28:15.560265+00:00`.
Fuente: [OSV querybatch](https://api.osv.dev/v1/querybatch).
Se conserva la respuesta completa. Cero avisos corresponde a estas versiones y
esta consulta; no demuestra ausencia de vulnerabilidades desconocidas ni
certifica el SO o la distribución JDK/Maven del host.

## Estructura y límites

`src/` y pom.xml permiten inspeccionar y reconstruir el proyecto entregado.
`build/target/` contiene las clases y productos temporales. `artifacts/` contiene
únicamente el candidato JAR. `qa/` conserva pruebas, informes, scripts,
configuración de controles, inventarios y logs; nada de esto se incluye en el
producto. Maven no genera target en la raíz del proyecto ni del multiproyecto.
No se crea un árbol paralelo iasi/outputs. Ambos árboles release y el iasi del
proyecto se comparan antes y después y permanecen sin cambios.

Los logs y XML generados por herramientas pueden conservar terminadores nativos
como evidencia; las fuentes propias se verifican en UTF-8 sin BOM y LF. Los
archivos de prueba temporales en scratch son reconstruibles a partir de las
fuentes retenidas y sus resultados están en qa/test-results.

La sintaxis de entorno queda pendiente de definición, como indica la propia
especificación. No se implementa descubrimiento de componentes, máquinas,
instalaciones, workflows, parser universal ni registro definitivo de acciones de
negocio. El candidato queda disponible para revisión en el proyecto correcto,
sin promoción a release ni cambios en la normativa.

## Refactorización de componentes comunes

La infraestructura reutilizable queda en:

- `org.iasi.common.logging`: Logger, Loggers, LogSink, LogEvent,
  MessageDefinition, Severity, Verbosity y los adaptadores ConsoleSink/FileLogSink.
- `org.iasi.common.i18n`: MessageCatalog, con base de recursos proporcionada por
  el consumidor y sin referencia a paquetes de la aplicación.
- `org.iasi.common.platform`: Platform y su detección de SO/runtime independiente.
- `org.iasi.setupdev`: entrada, CLI, configuración, ayuda y catálogo de eventos
  específico del launcher. Sus recursos de traducción siguen siendo propios.

Logger distribuye el mismo evento inmutable a dos puertos LogSink. LogEvent
valida la identidad y sanea texto y componente antes de llegar a cualquier
adaptador, incluso si se construye directamente. ConsoleSink decide visibilidad,
formato, colores y destino stdout/stderr. FileLogSink gestiona la persistencia
UTF-8 y el archivo por ejecución. El identificador de aplicación y componente se
inyecta, de modo que la biblioteca común no contiene nombres de este producto.

La sustitución por Log4j se concentra en una implementación de LogSink y en su
selección dentro de Loggers. El launcher conserva sus llamadas a la fachada y
sus definiciones de eventos. No se introduce una dependencia de Log4j para esta
entrega. La fachada y sus destinos actuales son de uso secuencial por ejecución;
no se presentan como servicios thread-safe.

Las pruebas nuevas comprueban adaptadores alternativos que reciben el mismo
objeto de evento, saneado previo, propagación del fallo de persistencia antes de
consola, cierre de ambos destinos con excepciones suprimidas y conservación de
streams prestados. También impiden dependencias desde common hacia setupdev o
Log4j y rechazan códigos mal formados antes de los destinos.

Todas las funciones y constructores declarados, en producción, pruebas y
SourceGate, cuentan con Javadoc de propósito o contrato. SourceGate 1.1.0 verifica
su presencia mediante DocTrees del compilador. La evidencia está en
`qa/method-documentation.txt`; la revisión de contenido comprueba responsabilidades,
precedencia, propiedad de recursos y errores, en lugar de limitarse a repetir
los nombres de los métodos. Los miembros implícitos de records no se cuentan
como declaraciones escritas por el proyecto.

El candidato final mantiene las reglas de parámetros y flags aprobadas en la
conversación, incluido force=false hardcoded y último flag de verbosidad ganador.
La refactorización no cambia dependencias, especificaciones ni release.
