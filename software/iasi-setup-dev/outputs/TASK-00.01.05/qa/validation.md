# TASK-00.01.05 — Ayuda del CLI

Referencia: `iasi/specifications/project/cli/help-cli.iasi`.

## Cambios

- La ayuda se imprime directamente en stdout, usando el catálogo internacionalizado.
- Título con versión real, descripción, seis secciones, alineación y líneas en blanco.
- La versión procede de `${project.version}`, filtrada por Maven en `version.properties`.
- El JAR se genera como `artifacts/iasi-setup-dev.jar` bajo esta tarea. El nombre es estable y la versión real permanece en los metadatos y la ayuda.
- Se aplica `javadoc.iasi`: descripciones en inglés para los 13 paquetes y 67 tipos propios, incluidos los tipos anidados y las pruebas. La responsabilidad se atribuye a Javier G. Grandez, según Git; `@since` y `@version` son 0.1.0, y la primera entrada documental de `@history` corresponde a 2026-11-19.
- Se retiran comentarios mecánicos de métodos y se conservan los contratos no evidentes. SourceGate ya no exige cobertura total de Javadoc en métodos.
- JavadocGate comprueba los mínimos estructurales y genera documentación con `@history` reconocido; queda integrado en la fase `verify`.
- No se ha modificado el parser, la precedencia ni el formateador de mensajes operativos.

## Verificación

- `mvn -q package`: correcto; 82 pruebas, sin errores ni fallos.
- `java outputs/TASK-00.01.05/qa/tools/JavadocGate.java . outputs/TASK-00.01.05`: correcto; 13 paquetes y 67 tipos, generación Javadoc sin errores ni avisos.
- `python outputs/TASK-00.01.05/qa/tools/check_initialization.py`: 16/16 casos correctos.
- `python outputs/TASK-00.01.05/qa/tools/check_help.py`: 4/4 casos correctos.
- Comparación exacta de ayuda en castellano, encabezados, líneas vacías y sangrías.
- Ayuda inglesa con la misma versión del POM y del recurso empaquetado.
- Ausencia de hora, códigos, etiquetas y colores en la ayuda.
- `-afh --config absent.toml --logs new-logs` muestra ayuda con RC 0 y conserva el árbol de máquinas y ficheros de prueba.
- Las pruebas de ConsoleSink conservan el formato operativo previo.

## Discrepancias e incidencias

- `--help` no está soportado por diseño: `--` identifica parámetros con valor. Se anuncia únicamente `-h`; no se ha incorporado un alias. La ejecución de `--help` conserva RC 16 y un diagnóstico operativo.
- La referencia menciona códigos en los mensajes operativos; el formato implementado previamente es `HH:mm:ss - mensaje`. Se conserva tal como exige el alcance de esta tarea.
- `mvn -q -DskipTests verify` sigue detenido en formatter-maven-plugin: su última ejecución señala `RC.java` como archivo no formateado. El bloqueo general de formato ya existía antes de esta regularización documental. Se formatearon únicamente los nuevos `package-info.java`; no se aplicó un reformateado general que alterase la escritura en columnas. El registro está en `verify.log`. El control Javadoc se ejecutó también de forma independiente y pasó.

## Evidencias

- `help-es.stdout.txt`, `help-en.stdout.txt`: salida real del JAR.
- `help-skips-operations.stdout.txt`: ayuda con flags operativos y configuración inexistente.
- `unsupported-long-help.stderr.txt`: diagnóstico de la forma no soportada.
- `help-checks.json`, `initialization-checks.json`: resultados de procesos.
- `test-results/`: resultados JUnit.
- `javadoc-structure.txt`, `javadoc-generation.log`, `javadoc/`: comprobación y documentación generada.
