# Prueba actual: bootstrap y fase 1

Orden operativo:
1. `services.toml`: directorios, unidades, instalar Git, clone/pull de **iasi-setup-ecosystem** solamente.
2. `packages.toml`: `[SDK]` en `C:\SDK`, `[software]` en ubicaciones predeterminadas. Se lanza mediante `IASI-Windows-Packages` al iniciar sesion el usuario, una vez existe `bootstrap.completed`.
3. `postinstall.toml`: contiene configuracion para la futura fase 2, incluida `[github]` para sincronizar la organizacion completa. **No se ejecuta todavia**.

No se ha validado esta entrega ejecutandola dentro de Hyper-V. Los programas de winget y sus rutas reales requieren verificacion.

Prueba desde cero (destructiva para iasi-dev2):

```powershell
.\bin\ps\setup.ps1 --config .\config\iasi-dev2 --path C:\Maquinas -f
```

Tras el primer arranque y provisionamiento, comprobar en la VM:

```powershell
Get-Content C:\ProgramData\IASI\bootstrap.log -Tail 30
Get-Content C:\ProgramData\IASI\packages.log -Tail 60
Test-Path C:\ProgramData\IASI\bootstrap.completed
Test-Path C:\ProgramData\IASI\packages.completed
```

Los errores deben detener la fase correspondiente; no se crean marcadores de finalizacion falsa.
