# TASK-00.01.06 — Descubrimiento de máquinas

Referencia: `iasi/specifications/project/cli/machine-discovery.iasi`.

## Cambio

`TargetDiscovery.discover` mantiene un único recorrido del primer nivel. El filtro `isMachineCandidate` acepta una carpeta solo si contiene directamente otra carpeta cuyo nombre sea `TargetDiscovery.MACHINE_CONFIG_DIRECTORY`, con valor predeterminado `config-data`.

El literal aparece una sola vez en el código de producción. La misma función recibe el directorio efectivo de `ctx`, independientemente de si proviene del CWD, CLI, TOML o entorno. No se leen configuraciones de las máquinas, no se exigen ficheros y no se modifica el sistema de archivos. Se conservan orden, selección por regex, avisos y tratamiento de errores de acceso del código anterior.

## Comprobaciones

- `mvn -q package`: correcto; 91 pruebas sin fallos ni errores, incluidas lectura del recurso y precedencia entre capas.
- `check_machine_discovery.py`: 8/8 procesos correctos. Raíces CWD, CLI, TOML y entorno; carpetas sin marcador excluidas; marcador como fichero excluido; marcador solo anidado excluido; resultados vacíos; selección regex y aviso por un target no candidato.
- Las pruebas unitarias aceptan tanto marcadores vacíos como contenido TOML incorrecto dentro de ellos: descubrimiento no interpreta ese contenido. También mantienen los errores de IO para raíces inexistentes o que sean ficheros.
- Cada comprobación de descubrimiento verifica que el árbol de archivos permanece sin cambios.
- Regresión de inicialización: 17/17 procesos correctos.
- Regresión de ayuda: 4/4 procesos correctos.
- JavadocGate: 13 paquetes, 74 tipos; documentación generada con `@history` reconocido.
- Ejecución real desde `outputs`: `resolvedTargets = []`, RC 0; los directorios de tareas dejan de considerarse máquinas.
- `mvn -q -DskipTests verify`: persiste el bloqueo del formateador general en `RC.java`. Se conserva en `verify.log`; no se reformateó código ajeno al alcance de descubrimiento.

## Artefacto

El JAR de uso se actualiza en `outputs/iasi-setup-dev.jar`, sin sufijo de versión, según la instrucción del usuario. Las evidencias y productos de esta tarea permanecen en `outputs/TASK-00.01.06/`.

## Recurso de configuración interno

Por instrucción posterior del usuario, Maven incluye el archivo del ecosistema `../../definitions/defaults.toml` como `org/iasi/setupdev/defaults.toml` dentro del JAR, sin una segunda copia de origen. Se corrigió `verbose = true` a `verbose = 1` para respetar el tipo entero vigente.

`InternalConfiguration` y `ExternalConfiguration` comparten `TomlConfiguration`. Las capas se acumulan como texto y se validan al final: hardcoded → recurso interno → fichero externo → entorno → CLI. El origen que abre un stream conserva la responsabilidad de cerrarlo.

El fallback de búsqueda procede ahora del recurso (`./definitions`), no del hardcoded `.`. Los defaults internos también establecen `./logs` y `C:/Machines`. Las pruebas de procesos sobrescriben únicamente la ubicación de máquinas con rutas temporales propias para no crear directorios fuera de QA; las pruebas unitarias y la comparación del recurso empaquetado comprueban todos los valores originales.
