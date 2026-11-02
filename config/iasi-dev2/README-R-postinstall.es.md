# R reproducible en iasi-dev2

La VM es descartable: la fuente de verdad es `config-data/renv.lock`, versionado en Git.

1. Primera vez: en `postinstall.toml`, `mode = 'bootstrap'`. Ejecute la fase 2 una vez, compruebe el archivo generado `config/iasi-dev2/config-data/renv.lock` y los paquetes.
2. Revise y confirme en Git `renv.lock` y los archivos de configuracion de `renv` creados en el directorio del catalogo. Cambie a `mode = 'restore'` y confirme la modificacion.
3. Cada nueva VM: ejecute la fase 2 con `mode = 'restore'`; no se cambian versiones sin una modificacion explicita de la linea base.

**Atencion:** en la primera ejecucion `renv` puede crear su estructura dentro de `config-data`, incluida una biblioteca local de paquetes; no versionar la biblioteca ni el directorio de caché. Revise lo que Git considera no rastreado. `renv.lock` fija las dependencias R, pero para repetir binarios exactamente es necesario mantener tambien R/Windows y las fuentes disponibles.

El QA verifica sincronizacion del entorno con el lockfile. La generacion inicial no supone aprobacion de la linea base.
