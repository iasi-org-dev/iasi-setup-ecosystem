# Windows IASI: instalación reanudable

- `FirstLogonCommands` invoca `launch-bootstrap.ps1` elevado.
- El lanzador copia el bootstrap y los servicios a `%ProgramData%\IASI\setup` y registra `IASI-Windows-Bootstrap` con identidad SYSTEM y disparador **AtStartup**. Lo inicia inmediatamente.
- Si Windows se reinicia a mitad, el disparador vuelve a ejecutar el bootstrap. Las tareas `services.toml` son idempotentes y se vuelven a verificar.
- Tras completar todas las operaciones se escribe `bootstrap.completed`, se elimina la tarea y se reinicia para aplicar los mapeos. No queda una tarea residente.
- Para descargas temporales como el instalador de Git se utiliza `$env:TEMP`; no se crean carpetas temporales fijas.
- El repositorio se clona por HTTPS si falta, o se actualiza con `git pull --ff-only` si está limpio.

## Verificación en iasi-dev2

```powershell
Get-Content C:\ProgramData\IASI\bootstrap.log -Tail 60
Test-Path C:\ProgramData\IASI\bootstrap.completed
Get-ScheduledTask -TaskName IASI-Windows-Bootstrap -ErrorAction SilentlyContinue
Test-Path C:\PRJ\iasi-dev\iasi-setup-ecosystem\.git
```

Resultado esperado: `True`, no existe la tarea, `True`. Si falla un paso, revisar el log.

**Limitación:** validación de estructura y TOML realizada; aún no comprobado en Windows/Hyper-V.
