# Contrato efectivo y decisiones de TASK-0001

La raíz del proyecto es `software/iasi-setup-dev` dentro del contenedor
multiproyecto `iasi-setup-ecosystem`. La normativa se consulta en el `iasi/` del
proyecto; los resultados se escriben en `outputs/TASK-0001` de esa raíz.
Esta entrega se crea desde cero y no modifica especificaciones ni estado de tareas.

Las instrucciones explícitas del usuario en esta conversación prevalecen sobre
los textos anteriores que aún describen otro contrato:

| Texto anterior | Contrato aplicado por instrucción del usuario |
| --- | --- |
| Ecosystem como proyecto | Ecosystem como contenedor multiproyecto; proyecto iasi-setup-dev |
| `--config` como directorio | Archivo externo de valores para esta instancia |
| `--log` y `defaults.log` de setup.toml | `--logs` y clave `logs` de las capas de parámetros |
| Configuración de máquinas bajo `--config` | Definiciones de máquinas bajo `--definitions` |
| Incompatibilidad entre v/V/s | Orden secuencial; último flag de verbosidad gana, incluso agrupado |
| force en configuración | `force=false` hardcoded; solo -f lo activa |

Se admite un recurso TOML interno opcional antes del externo, como confirmó el
usuario. El archivo particular `definitions/defaults.toml` es externo y cambia
por máquina: no se empaqueta ni se carga automáticamente. Una copia de ese
archivo se conserva en `qa/inputs` como entrada de prueba, no como default del
ejecutable. La capa de entorno está pendiente de definición y no se implementa
ninguna sintaxis supuesta. No se implementa un parser universal.

Decisiones de validación de esta entrega: solo se permiten definitions/machines/
logs como cadenas no vacías y verbose como booleano; se rechazan claves
desconocidas, incluido force. El TOML debe ser sintácticamente válido. Un archivo
externo explícito ausente o ilegible falla, sin fallback silencioso. Los parámetros
largos repetidos siguen la secuencia de la CLI y gana el último; las capas no
añaden nombres de parámetros. Estas decisiones locales se documentan para su
revisión y no se presentan como aprobación de los borradores.

`Options` realiza el análisis preliminar sin efectos: obtiene controles, valores
explícitos y flags en orden. `Configuration` inicia los hardcoded, superpone el
recurso interno, el externo y la CLI, resuelve rutas y valida. Solo un Settings
completo permite abrir el log. Main resuelve primero la ayuda, por lo que una
petición de ayuda válida no consulta ninguna configuración ni plataforma.

Main expone parsear, seleccionar comando, ayudar o resolver configuración,
iniciar mensajes, diagnosticar y resumir. Platform recibe propiedades inyectadas
para probar SO y arquitecturas sin depender del host ni de un hipervisor. Command
comparte las definiciones usadas para reconocimiento y listado de ayuda. Los
contextos create/workflow release siguen sin ejecutar operaciones.

Aplicabilidad de la normativa corporativa aprobada actual:

- CODE-ENC/EOL/LAYOUT: bytes UTF-8 sin BOM, LF y estructura física verificadas.
- JAVA-NAME/FMT/STR/SW: nombres y responsabilidades revisados; Eclipse con cuatro
  espacios y AST complementario para if de una instrucción; brazos switch simples.
- JAVA-CON-001/002: máximo 60 líneas efectivas y 3 niveles por método/constructor;
  lambdas evaluadas separadamente para complejidad y profundidad.
- QUAL/JAVA-CYC y COG: métricas individuales, límites 10 y 15 y analizador declarado.
- JAVA-VER y TECH-VER/SEC: versiones fijadas, herramientas reales registradas,
  inventario efectivo congelado y evaluación OSV de ejecución, pruebas y plugins.
- WF-DIR/OUT-001/OUT-002: un árbol por tarea; build/target, artifacts y qa separados.
- WF-IN/SPEC: los originales son archivo de contexto; los borradores siguen siendo
  borradores y no se generan normas nuevas ni se alteran las existentes.
- WF-QA/REL: controles objetivos sobre el candidato y sin promoción a release.

El formatter-maven-plugin 2.24.1 usa Eclipse JDT 3.37.0 y una configuración fijada
en `qa/config/eclipse.xml`; verify ejecuta validate sin modificar fuentes. La
anchura 160 permite conservar if de una instrucción en la misma línea y firmas
descriptivas; las 120 columnas son una recomendación y se revisa legibilidad.

IASI SourceGate 1.1.0 usa `JavacTask.parse` de JDK 25. Analiza fuentes principales,
pruebas y su propio código, sin cargar ni ejecutar sus clases. El CSV identifica
archivo, callable y línea. Longitud efectiva cuenta desde firma sin anotaciones
hasta llave final, excluyendo comentarios y líneas vacías con reconocimiento de
literales. Para lambdas la longitud es 0 como no aplicable a métodos/constructores.

La ciclomática es 1 + if + bucles + catch + ternarios + brazos case no default +
cada &&/||. La cognitiva suma 1+profundidad por if/bucle/catch/switch/ternario,
1 por else y 1 por &&/||. Else-if no añade nivel; else con bloque sí ocupa nivel
en su camino; try/finally y case por sí solos no lo incrementan. Clases anidadas y
lambdas se analizan separadamente. No se afirma equivalencia con Sonar. No se
puntúan recursión o saltos etiquetados; la revisión confirma que no se usan en el
producto ni sus pruebas. El gate incluye regresiones de métricas conocidas,
comentarios, else-if y defectos deliberados de formato, BOM, longitud, profundidad
y complejidad. No hay excepciones concedidas a los máximos obligatorios.

La selección inicial de herramientas añade overrides explícitos para evitar las
dependencias vulnerables originales conocidas de plugins: Jackson 2.18.11,
Guava 33.7.2-jre, BeanUtils 1.11.0, Commons IO 2.14.0 en compiler, Commons Lang
3.18.0, Plexus Utils 4.0.3 o 3.6.1 en shade, Snappy 0.5, jsoup 1.23.2 y
Aircompressor 2.0.3 en la herramienta de inspección. Es una selección inicial de
este proyecto nuevo, no un cambio a una línea aprobada de una entrega anterior.
Su impacto se limita a los class realms de construcción/inspección; el runtime
del launcher usa TOMLJ 1.1.1 y sus transitivas ANTLR 4.11.1 y checker-qual 3.21.2.
La compatibilidad se valida con builds limpios, pruebas y uso real del JAR.

La resolución de plugins por sus POM no acredita los overrides: el inventario se
extrae de los class realms realmente poblados y del provider de Surefire. Solo se
retienen coordenadas y salida normal de Maven, nunca el debug completo de
propiedades. La línea inicial se registra explícitamente una vez; las siguientes
ejecuciones fallan ante cambios del inventario. Una nueva selección requiere
revisión de compatibilidad, seguridad, migración y rollback conforme a las normas.
No se sobrescribe automáticamente el baseline para ocultar discrepancias.

Los logs y reportes generados por Maven/Surefire pueden conservar terminadores
nativos como evidencia. Las fuentes, recursos, configuraciones y documentación
propias se comprueban en UTF-8 sin BOM y LF. Los archivos temporales de pruebas
usan scratch del sistema; fuentes de pruebas y sus resultados reproducibles se
conservan bajo esta tarea. El JAR solo incluye producto y licencias.


Refactorización solicitada posteriormente: se separan logging, localización y
detección de plataforma en org.iasi.common. El catálogo del launcher implementa
MessageDefinition; Logger depende de ese contrato y de destinos LogSink, no de
su enum concreto. Los nombres de recursos, componente y aplicación se inyectan.
Loggers concentra la selección del backend. ConsoleSink y FileLogSink conservan
las políticas observables de esta entrega. Un futuro adaptador Log4j puede
sustituir persistencia sin modificar las llamadas del launcher. Las APIs públicas
y las funciones internas documentan intención, errores y propiedad de recursos;
SourceGate comprueba la presencia de Javadoc en todas las declaraciones propias.
