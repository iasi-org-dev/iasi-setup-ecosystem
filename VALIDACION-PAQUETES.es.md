# Prueba de iasi-dev2 (solo services + packages)

El `FirstLogonCommands` instala y programa las dos tareas temporales: `IASI-Windows-Bootstrap` como SYSTEM y `IASI-Windows-Packages` como usuario Windows elevado. Tras terminar servicios, el bootstrap reinicia Windows y la tarea de paquetes comienza al siguiente inicio de sesión. La tarea se elimina al completarse la fase. Si falla permanece para reintento en el siguiente inicio.

Ejecutar en Legion: `./bin/ps/setup.ps1 --config ./config/iasi-dev2 --path C:\Maquinas -f` (destructivo: recrea la VM). Instalar Windows manualmente e iniciar sesión tras el reinicio del bootstrap.

En la VM: revisar `%ProgramData%\IASI\bootstrap.log`, `%ProgramData%\IASI\packages.log`, `%ProgramData%\IASI\packages.completed` y el directorio `C:\SDK`.

**Excluido de esta versión:** `custom`, `postinstall` y WSL. Winget se ejecuta en el usuario real; algunos instaladores pueden ignorar `--location`, por lo que el destino físico necesita comprobación. La instalación real no se ha probado aquí.
