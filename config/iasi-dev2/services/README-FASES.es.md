# Fases de iasi-dev2

1. `services.toml`: bootstrap como SYSTEM, directorios, unidades, Git y repositorios.
2. `packages.toml`: aplicaciones bajo C:\SDK (en la cuenta de usuario real, como administrador).
3. `wsl.ps1`: activar WSL y migrar Ubuntu 24.04 a C:\Machines\IASI bajo esa misma cuenta; puede requerir reinicio.
4. `postinstall.toml`: extensiones VS Code y paquetes R.

La fase de software y postinstalacion se ejecuta mediante `bin\ps\windows\run-user-phases.ps1 -ConfigDir <ruta>` desde una sesion elevada del usuario de la VM. Aun NO esta automatizada desde el host Hyper-V; no se declara la maquina completamente aprovisionada tras el bootstrap. Los scripts de servicios se ejecutan como SYSTEM.

No se desregistra Ubuntu hasta comprobar IASI. La importacion WSL es por usuario, no por SYSTEM.
