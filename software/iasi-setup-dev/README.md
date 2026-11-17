# IASI Setup Dev

Software Java 25 dentro del contenedor multiproyecto `iasi-setup-ecosystem`.
Cada tarea evoluciona las mismas fuentes en `src/`. La tarea actual es
`TASK-00.01.03` (Execution Context); sus productos y evidencias residen en
`outputs/TASK-00.01.03/`. Las entregas TASK-0001 y TASK-0002 permanecen intactas.

Desde esta raíz, con JDK 25 y Maven:

```powershell
mvn -B -ntp clean verify
java -jar outputs/TASK-00.01.03/artifacts/iasi-setup-dev-0.1.0.jar help
java -jar outputs/TASK-00.01.03/artifacts/iasi-setup-dev-0.1.0.jar platform -V --logs outputs/TASK-00.01.03/qa/manual
python outputs/TASK-00.01.03/qa/tools/verify.py
```

El último comando requiere Python 3.10+, Windows para el lanzador Maven y acceso
HTTPS a Maven Central/OSV. Ejecuta dos builds limpios reproducibles, inventario
efectivo y pruebas de procesos. El producto y la compilación Maven usan APIs
Java portables; la ejecución física de QA se realiza en Windows.

| Paquete | Responsabilidad |
| --- | --- |
| `org.iasi.base` | Constantes RC enteras y valores de verbosidad |
| `org.iasisetupdev.core` | Contexto y configuración específica de esta aplicación |
| `org.iasi.common.operation` | Datos locales de una operación y su máscara RC entera |
| `org.iasi.common.logging` | Fachada y destinos de archivo/consola intercambiables |
| `org.iasi.common.i18n` | Catálogos de mensajes parametrizados |
| `org.iasi.common.platform` | Identificación independiente del host |
| `org.iasi.setupdev` | Bootstrap, CLI, coordinación y punto de salida |

Base solo depende del JDK y sus propios tipos. Common puede depender de base;
setupdev utiliza los servicios comunes y el contexto. El backend de logging
sigue sustituible mediante LogSink y la composición en Loggers.

## Contexto único

El bootstrap resuelve y valida antes de llamar una sola vez a
`Context.initialize(configuration)`. Hasta entonces, getInstance rechaza
el acceso: no existe una configuración operativa provisional. Otros componentes
utilizan la referencia convencional `ctx`:

```java
Context ctx = Context.getInstance();
ctx.setRC(RC.INFO);
ctx.setRC(RC.WARNING);
ctx.setRC(RC.OK);      // Conserva 0x06; no reinicia el acumulado.
int rc = ctx.getRC();
```

El contexto conserva configuración efectiva inmutable, UUID de ejecución e
instante inicial. Solo el RC es mutable. La publicación utiliza métodos estáticos
sincronizados; setRC/getRC usan el monitor de la instancia para evitar pérdidas
de actualizaciones y garantizar visibilidad. No se añaden atomics, workers ni
colas al producto. La referencia y sus datos estables no se reemplazan.

Una segunda initialize falla sin modificar la primera instancia. No hay reset,
recarga dinámica ni varias ejecuciones independientes dentro de la misma JVM.
Para iniciar otra ejecución se utiliza otro proceso, también en las pruebas.
El contexto no contiene Map genéricos, entidades, colecciones de negocio o
setters arbitrarios. Las referencias a servicios solo se incorporarán cuando
haya una necesidad transversal justificada: el logger actual mantiene propiedad
y cierre local en el coordinador, sin invertir dependencias de base hacia common.

## RC enteros y flujo

| Constante | Valor |
| --- | --- |
| `RC.OK` | `0x00` |
| `RC.NOTHING_TO_DO` | `0x01` |
| `RC.INFO` | `0x02` |
| `RC.WARNING` | `0x04` |
| `RC.ATTENTION` | `0x08` |
| `RC.ERROR` | `0x10` |
| `RC.SEVERE` | `0x20` |
| `RC.FATAL` | `0x40` |

Son public static final int, nunca enums. Se combinan directamente con OR y no
se asignan nombres a valores compuestos. 0x80 y Skip no están definidos.
RC.isValid permite validar máscaras en fronteras de entrada; un exit code nativo
externo requiere siempre interpretación y mapeo explícitos.

setRC recibe una máscara IASI válida y ejecuta únicamente `rc |= value` bajo
sincronización. No la sustituye ni valida mediante excepciones, y no ejecuta
throw, return, callbacks, saltos o salida del proceso. OK y repeticiones no borran
bits. El código que detecta una situación determina su flujo funcional; Fatal
no detiene por sí mismo la ejecución. OperationResult conserva RC locales como
int y valida su rango antes de que el coordinador los acumule en ctx.

Mensajes ordinarios, colores, idioma y filtros no alteran el RC. Una circunstancia
informativa relevante añade Info explícitamente. De 0 a 15 las máscaras son no
erróneas; de 16 a 127 contienen algún indicador de error. No se normalizan los
resultados a cero/uno al devolverlos al SO.

La ayuda válida devuelve OK sin publicar ctx ni crear archivos. Un fallo durante
bootstrap devuelve un RC local porque todavía no existe contexto operativo.
Después de inicializar, los fallos controlados añaden Error a ctx; un fallo
inesperado añade Fatal sin borrar bits previos. Los recursos se cierran mediante
try-with-resources y solo el final de main llama a System.exit con el RC final.

## CLI conservado

--config selecciona un archivo externo para esa instancia. Las capas son
hardcoded, recurso interno opcional, archivo externo y CLI explícita. Cada capa
sustituye solo las claves que contiene. Se admiten definitions, machines, logs y
verbose. Force es false hardcoded y solo -f lo activa. El último -v/-V/-s gana,
también dentro de grupos. Las rutas relativas se resuelven contra el CWD inicial;
los tres directorios usan `.` por defecto.

No se descubre automáticamente defaults.toml/setup.toml. El archivo particular
de una máquina no se empaqueta dentro del JAR. El selector de configuración por
entorno sigue pendiente de definición. La ayuda no carga fuentes ni consulta el
host. Platform diagnostica el SO, no hipervisores; create y workflow release
siguen siendo contextos de ayuda sin ejecución operativa.

Los errores de entrada/IO controlados devuelven RC.ERROR, el host desconocido
marca Error y el diagnóstico normal conserva OK. Los procesos de QA inyectan
circunstancias Info, Warning, NothingToDo y combinaciones sin añadir parámetros
artificiales al CLI del producto.

Informe: `outputs/TASK-00.01.03/qa/qa-report.md`. Fuentes y pruebas tienen Javadoc;
Maven verify comprueba documentación, formato no mutante, codificación y métricas.
No se promociona a release ni se modifican documentos normativos o de tareas.
