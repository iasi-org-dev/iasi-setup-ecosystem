# IASI Setup Dev — TASK-0001

Base nueva del launcher Java 25. Proyecto:
`J:/iasi-setup-ecosystem/software/iasi-setup-dev`.
Todos los resultados de la tarea están en su propio `outputs/TASK-0001/`.

Desde este directorio de tarea, con Java 25 y Maven en PATH:

```powershell
mvn -B -ntp clean verify
java -jar artifacts/iasi-setup-dev-0.1.0.jar help
java -jar artifacts/iasi-setup-dev-0.1.0.jar workflow help
java -jar artifacts/iasi-setup-dev-0.1.0.jar create -h
java -jar artifacts/iasi-setup-dev-0.1.0.jar platform -v -s -V --logs qa/manual-logs
java -jar artifacts/iasi-setup-dev-0.1.0.jar platform --config "J:/iasi-setup-ecosystem/definitions/defaults.toml" --logs qa/manual-logs
```

El primer comando compila, ejecuta las pruebas y comprueba formato sin modificarlo,
codificación, longitud, anidamiento y complejidades. Para aplicar el formato de
forma explícita: `mvn formatter:format`. Para el gate completo del candidato, con
Python 3.10+, Windows y acceso HTTPS a Maven Central y OSV:

```powershell
python qa/tools/verify.py
```

El gate ejecuta dos builds limpios, comprueba que el JAR sea reproducible, captura
los class realms efectivos de Maven, contrasta el inventario congelado, consulta
vulnerabilidades y prueba el JAR en procesos separados. La captura de Maven usa
su lanzador Windows; el código Java y su compilación Maven usan APIs portables.

| Directorio | Función |
| --- | --- |
| `src/`, `pom.xml` | Fuentes, recursos y pruebas de esta entrega |
| `build/target/` | Productos intermedios reconstruibles |
| `artifacts/` | Único JAR candidato autónomo |
| `qa/` | Gate, configuración, informes, métricas, inventarios y logs |

El archivo externo contiene estas cuatro entradas opcionales:

```toml
definitions = "./definitions"
machines = "C:/Machines"
logs = "./logs"
verbose = true
```

Cada capa sustituye únicamente las claves que aporta:

1. Hardcoded: directorios `.` y `verbose=false`; `force=false`.
2. Recurso opcional del JAR: `/org/iasi/setupdev/defaults.toml`, si existe.
3. Archivo externo seleccionado explícitamente con `--config <archivo>`.
4. Argumentos explícitos de esa instancia.

`force` queda fuera de los archivos de configuración: solo `-f` lo activa para
esa instancia. Incluir `force` en TOML se rechaza como clave no admitida.
El JAR candidato no contiene un TOML interno ni el archivo particular de una
máquina. No busca automáticamente `defaults.toml` ni `setup.toml`. Las variables
de entorno de configuración quedan pendientes de un selector y una regla de
nombres definidos; no se inventa una opción para ellas.

Las rutas relativas de todas las capas se interpretan respecto del CWD al iniciar
el proceso, incluido el contenido del archivo externo. No se interpretan respecto
del JAR ni del directorio que contiene el TOML. Por ejemplo, `./definitions` en
el archivo externo significa `definitions` bajo el directorio desde el que se
lanza Java. `C:/Machines` es un valor específico de Windows, no un default
hardcoded ni un valor portable entre sistemas.

`--definitions`, `--machines` y `--logs` aceptan directorios independientes.
`--config` acepta un archivo TOML. Todos requieren un valor separado; un valor
se consume como un único argumento literal. Las claves desconocidas, tipos
incorrectos, TOML defectuoso y rutas existentes que sean archivos en vez de
directorios se rechazan. Un archivo indicado pero inexistente produce error.
Se valida el conjunto antes de crear el log; no se aplica una configuración parcial.
Los parámetros largos repetidos se resuelven en orden: gana el último.

Los flags se procesan de izquierda a derecha, también dentro de los grupos:

| CLI | Consola efectiva |
| --- | --- |
| `-v -s -V` o `-vsV` | INFO, SUCCESS, WARNING, ERROR, DEBUG, TRACE |
| `-V -s` o `-Vs` | Solo ERROR |
| `-s -v` o `-sv` | INFO, SUCCESS, WARNING, ERROR, DEBUG |

El último flag de verbosidad sobrescribe la configuración, sin incompatibilidad
entre `-v`, `-V` y `-s`. La persistencia del log no depende de ese filtro; TRACE
solo se guarda con `-Diasi.log.trace=true` antes de `-jar`. Los logs se crean
directamente en el directorio efectivo de logs, sin añadir otro subdirectorio.

`platform` es el diagnóstico de esta tarea: muestra SO, versión y arquitectura;
con `-V` añade runtime y proveedor. No prueba hipervisores. `create` y
`workflow release` son contextos de ayuda de ejemplo; ejecutarlos devuelve error.
La ayuda no carga configuración, no consulta el host ni crea logs o directorios.
Se rechazan `--help`, `help workflow`, targets y órdenes no registradas.

Los mensajes usan `HH:mm:ss - LLLNNMMM - Mensaje`, identificadores estables y
catálogos español/inglés. El locale de Java selecciona idioma y el fallback es
inglés. stdout/stderr del launcher son UTF-8; los errores van a stderr. ANSI se
habilita solo en una consola con indicios de soporte y sin `NO_COLOR`; los logs
no llevan ANSI. No se imprimen argumentos inválidos ni excepciones crudas, y se
sanean patrones de secretos y controles antes de emitir los dos destinos.

| Código de salida | Resultado |
| --- | --- |
| 0 | Ayuda válida o diagnóstico de una familia reconocida |
| 1 | Error de lectura, acceso a directorios o escritura del log |
| 2 | CLI/configuración inválida o acción todavía no implementada |
| 3 | SO desconocido o no soportado |

Las decisiones y la precedencia respecto de documentos antiguos se explican en
`qa/contract-decisions.md`. El informe final está en `qa/qa-report.md`.
No hay creación de máquinas, instalación, descubrimiento de componentes ni
workflows. El resultado queda en outputs; no se promociona a release.


Organización para reutilización:

| Paquete | Responsabilidad |
| --- | --- |
| `org.iasi.common.logging` | Fachada de eventos, puerto LogSink y adaptadores de consola/archivo |
| `org.iasi.common.i18n` | Catálogo de recursos independiente de la aplicación |
| `org.iasi.common.platform` | Descripción y detección portable del host |
| `org.iasi.setupdev` | CLI, configuración, ayuda y eventos propios del launcher |

El catálogo de eventos de cada aplicación implementa MessageDefinition. Logger
localiza y entrega un LogEvent inmutable y saneado a los destinos. Loggers es el
punto de composición del backend predeterminado. Para incorporar Log4j, se
implementa LogSink y se selecciona desde ese punto; las llamadas emit del
launcher conservan su contrato. La biblioteca común no referencia setupdev y
recibe explícitamente nombre de catálogo, aplicación y componente.

Las funciones y constructores declarados tienen Javadoc de contrato, también en
pruebas y herramientas QA. SourceGate verifica su presencia junto con estilo y
métricas. Los destinos poseen sus recursos: archivo cierra su writer y consola
solo hace flush de los streams prestados. Logger intenta cerrar ambos destinos
y preserva fallos secundarios. El uso actual es secuencial por ejecución.
