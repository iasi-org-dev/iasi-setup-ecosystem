# IASI DEV2 - Post-install

Aplicar el ZIP sobre la raiz de `iasi-setup-ecosystem` **dentro de la VM iasi-dev2**, sin cambiar su estructura de directorios. Guardar primero una copia de los ficheros reemplazados.

## Ejecucion

Abrir PowerShell **como administrador** dentro de `iasi-dev2`, situarse en la raiz del repositorio y ejecutar:

```powershell
.\bin\ps\windows\run-user-phases.ps1 -ConfigDir .\config\iasi-dev2
```

Este comando ejecuta la instalacion de software Windows declarado con winget (fase 1) y despues post-install (fase 2). Puede descargar programas grandes, especialmente MiKTeX, RStudio, Java y otros. **No usar `-f` ni ejecutar `setup.ps1`**: eso no corresponde a esta tarea. El script no instala WSL ni recrea maquinas.

Post-install instala solo la extension `ms-vscode.powershell` y comprueba que figura en `code --list-extensions`; mantiene las demas extensiones declaradas sin instalarlas. R conserva la lista de paquetes pero `enabled=false`; no inicializa ni modifica `renv.lock`.

La fase de GitHub consulta repositorios **publicos** de `iasi-org-dev`, clona los ausentes y actualiza con `git pull --ff-only` los existentes limpios. Si un repositorio tiene modificaciones locales, **no se actualiza**; se informa `QA UNKNOWN` y se continua sin alterar archivos. Los repositorios privados quedan fuera.

Las unidades P: -> C:\PRJ e I: -> C:\PRJ\iasi-dev ya las crea `action-drives.ps1` en bootstrap mediante el registro; no hay que duplicarlas en post-install. Comprobarlas tras reiniciar si aun no aparecen.

Logs: `C:\ProgramData\IASI\user-phases.log`.

## Limites de QA

La sintaxis y estructura del ZIP se han revisado de forma estatica, pero **no se ha ejecutado dentro de la VM Windows**, por lo que la fase no puede marcarse PASS hasta verificar la salida real. El programa `winget` necesita funcionar en la sesion interactiva del usuario.
