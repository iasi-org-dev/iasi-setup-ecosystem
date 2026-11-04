IASI WSL BOOTSTRAP
Colocar bin/ps/wsl.ps1 y config/wsl.toml en las rutas indicadas.
En caso de WSL predeterminado funcional, no importa otra instancia.
No usa wsl --unregister ni elimina VHDX/distribuciones registradas.
Si necesita reinicio: REBOOT_REQUIRED y codigo 194. Reiniciar Windows manualmente y repetir el comando original.
Con -f, el orquestador NO pasa -f al adaptador WSL.
IMPORTANTE: no ejecutar -f del ecosistema completo, pues sigue siendo destructivo para las VMs Hyper-V.
Prueba inicial no destructiva: .\bin\ps\setup.ps1 --config .\config\wsl.toml
NOTA: validacion en Windows/Legion pendiente.
