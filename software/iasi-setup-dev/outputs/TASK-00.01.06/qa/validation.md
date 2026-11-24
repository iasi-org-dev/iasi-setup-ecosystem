# TASK-00.01.06 — Descubrimiento de máquinas

Referencia: `iasi/specifications/project/cli/machine-discovery.iasi`.

## Cambio

`TargetDiscovery.discover` mantiene un único recorrido del primer nivel. El filtro `isMachineCandidate` acepta una carpeta solo si contiene directamente otra carpeta cuyo nombre sea `TargetDiscovery.MACHINE_CONFIG_DIRECTORY`, con valor predeterminado `config-data`.

El literal aparece una sola vez en el código de producción. La misma función recibe el directorio efectivo de `ctx`, independientemente de si proviene del CWD, CLI, TOML o entorno. No se leen configuraciones de las máquinas, no se exigen ficheros y no se modifica el sistema de archivos. Se conservan orden, selección por regex, avisos y tratamiento de errores de acceso del código anterior.

## Comprobaciones

- `mvn -q package`: correcto; 94 pruebas sin fallos ni errores, incluidas lectura del recurso, precedencia entre capas e interpretación de privilegios.
- `check_machine_discovery.py`: 8/8 procesos correctos. Raíces CWD, CLI, TOML y entorno; carpetas sin marcador excluidas; marcador como fichero excluido; marcador solo anidado excluido; resultados vacíos; selección regex y aviso por un target no candidato.
- Las pruebas unitarias aceptan tanto marcadores vacíos como contenido TOML incorrecto dentro de ellos: descubrimiento no interpreta ese contenido. También mantienen los errores de IO para raíces inexistentes o que sean ficheros.
- Cada comprobación de descubrimiento verifica que el árbol de archivos permanece sin cambios.
- Regresión de inicialización: 17/17 procesos correctos.
- Regresión de ayuda: 4/4 procesos correctos.
- JavadocGate: 13 paquetes, 76 tipos; documentación generada con `@history` reconocido.
- Ejecución real desde `outputs`: `resolvedTargets = []`, RC 0; los directorios de tareas dejan de considerarse máquinas.
- `mvn -q -DskipTests verify`: persiste el bloqueo del formateador general en `RC.java`. Se conserva en `verify.log`; no se reformateó código ajeno al alcance de descubrimiento.

## Artefacto

El JAR de uso se actualiza en `outputs/iasi-setup-dev.jar`, sin sufijo de versión, según la instrucción del usuario. Las evidencias y productos de esta tarea permanecen en `outputs/TASK-00.01.06/`.

## Recurso de configuración interno

Por instrucción posterior del usuario, Maven incluye el archivo del ecosistema `../../definitions/defaults.toml` como `org/iasi/setupdev/defaults.toml` dentro del JAR, sin una segunda copia de origen. Se corrigió `verbose = true` a `verbose = 1` para respetar el tipo entero vigente.

`InternalConfiguration` y `ExternalConfiguration` comparten `TomlConfiguration`. Las capas se acumulan como texto y se validan al final: hardcoded → recurso interno → fichero externo → entorno → CLI. El origen que abre un stream conserva la responsabilidad de cerrarlo.

El fallback de búsqueda procede ahora del recurso (`./definitions`), no del hardcoded `.`. Los defaults internos también establecen `./logs` y `C:/Machines`. Las pruebas de procesos sobrescriben únicamente la ubicación de máquinas con rutas temporales propias para no crear directorios fuera de QA; las pruebas unitarias y la comparación del recurso empaquetado comprueban todos los valores originales.

## Comprobación inicial de administrador

Por instrucción posterior del usuario, `App.main` crea primero el singleton `Context`, obtiene y guarda su OS con `setOS(getOperatingSystem())`, comprueba después administrador usando `ctx.getOS()` y solo entonces ejecuta `run` e inicializa la aplicación. El contexto conserva el OS, pero no un estado de administrador: la falta de privilegios termina el proceso. Ambos chequeos preceden a las definiciones, argumentos, ayuda y configuración. `Initializer` vuelve a dedicarse a sus capas. La detección reutilizable reside en `org.iasi.common.platform.AdministratorPrivileges` y recibe el OS ya identificado; no solicita elevación ni ofrece una propiedad de omisión.

En Windows se consulta el token efectivo con `WindowsPrincipal.IsInRole(Administrator)` en un proceso hijo que hereda la elevación. [Microsoft documenta que devuelve false con el token estándar incluso si el usuario pertenece al grupo Administradores](https://learn.microsoft.com/en-us/dotnet/api/system.security.principal.windowsprincipal.isinrole). En Linux y macOS se comprueba el UID efectivo mediante `/usr/bin/id -u`. Un resultado no verificable detiene la ejecución con su propio diagnóstico.

`check_privileges.py` ha pasado 6/6 casos en esta sesión no elevada: sin argumentos, ayuda, configuración inexistente, sintaxis incorrecta, directorio de logs y OS no soportado. Los cinco primeros devuelven RC 16 con el mensaje de administrador antes de procesar las entradas; el último verifica que el rechazo del OS tiene prioridad. No hay stdout ni modificaciones en el sistema de archivos. Los casos elevado/no elevado y resultados no verificables se cubren además por pruebas unitarias del detector.

Las 29 comprobaciones operativas anteriores se ejecutaron antes de incorporar este requisito. Ahora requieren una consola elevada y no se han vuelto a ejecutar en esta sesión sin privilegios. El recorrido completo como administrador queda pendiente de una ejecución elevada; no se ha simulado elevación para superarlo.
