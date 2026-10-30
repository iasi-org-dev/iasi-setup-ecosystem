# Cambio de catálogo

- `packages.toml` usa `[SDK]`, `[software]`, `[custom]` con valores booleanos.
- El lector TOML admite ahora nombres de clave entre comillas y comentarios en línea.
- `install-software.ps1` interpreta ambas categorías; `custom=true` se detiene explícitamente hasta disponer del adaptador.
- `postinstall.toml` permanece separado.
- **IMPORTANTE:** el orquestador no lanza aún automáticamente las fases de usuario. Para probar sobre la VM ya creada, copiar el repositorio actualizado a la VM y ejecutar elevado bajo su usuario: `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\bin\ps\windows\run-user-phases.ps1 -ConfigDir .\config\iasi-dev2`.
- La ubicación solicitada con `winget --location` no equivale a ubicación garantizada: requiere verificación por instalador.
- Cambios manuales del repositorio de Legion no están incluidos si se realizaron después del último ZIP; comparar antes de sustituir.
