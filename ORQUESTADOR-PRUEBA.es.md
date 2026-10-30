# Prueba integral del orquestador IASI

## Ejecutar

Desde PowerShell administrador en Legion:

```powershell
.\bin\ps\setup.ps1 --path C:\Maquinas -f
```

**ATENCIÓN:** `-f` es destructivo para todas las máquinas incluidas en `config/setup.toml`: `iasi-dev2`, `iasi-tools`, `iasi-models`. No utilizar si se desean conservar sus VHDX.

`setup.ps1` recorre `config/setup.toml` en orden y llama a `hyper-v.ps1` por VM. Para `interactive` se detiene, pide terminar Windows manualmente y solo continúa si PowerShell Direct verifica `bootstrap.completed` y `packages.completed`, junto a la desaparición de ambas tareas temporales. La pulsación de ENTER es una petición de verificación, no un salto de control. Q detiene todo. Para Ubuntu se conserva confirmación manual de servicios, no un verificador automatizado.

Sin `-f`, preserva las VM existentes y permite reanudar el proceso. Con `--config`, actúa sobre una sola máquina. `-l` mantiene el comportamiento previo de dejar apagado y omitir la espera.

## Limitaciones

No se ha ejecutado en Hyper-V desde este entorno. La verificación de Windows usa las credenciales de `config-data/setup.toml` existentes en el proyecto: conviene eliminar esa contraseña en texto claro en una evolución posterior. `packages.completed` es la señal del instalador existente, no una auditoría individual de las aplicaciones. No se ejecuta postinstall.
