# IASI: orquestación del ecosistema

## Comandos

En Legion, PowerShell administrador, desde la raíz del repositorio:

- `./bin/ps/setup.ps1 --path C:\Maquinas`: orquesta todos los componentes de `config/setup.toml` en orden. **Nunca recrea máquinas existentes**.
- `./bin/ps/setup.ps1 --config ./config/iasi-dev2 --path C:\Maquinas`: solo iasi-dev2, sin destruirla.
- `./bin/ps/setup.ps1 --config ./config/iasi-dev2 --path C:\Maquinas -f`: **destruye y recrea únicamente iasi-dev2**.
- `./bin/ps/hyper-v.ps1 --config ./config/iasi-dev2 --path C:\Maquinas -f`: ejecutor bajo nivel, sigue disponible.

**Sin `--config` se usa el orden declarativo**: dev2, tools, models. `iasi-work` permanece fuera hasta revisión. Nunca se permite `-f` en toda la instalación.

Para Windows interactivo, `hyper-v.ps1` deja la VM apagada; `setup.ps1` espera a que el operador la instale y pulse ENTER. Después verifica con PowerShell Direct en la VM: marca de bootstrap, Git, SDK, repositorio y eliminación de la tarea temporal. Si falta algo, no continúa. `Q` aborta el orquestador y permite reanudar volviendo a ejecutarlo.

**Precaución:** PowerShell Direct requiere que la cuenta local declarada en `config-data/setup.toml` coincida con la creada en la VM. En este entorno de laboratorio ya existe una contraseña de demostración en ese archivo, que no debe distribuirse ni reutilizarse en entornos reales. No se ha probado aún la conexión PowerShell Direct desde Legion.

En Linux, la comprobación de guest readiness no está automatizada: se solicita confirmación explícita del operador después de verificar servicios. Confirmar manualmente **no** genera una atestación técnica.

## Software y GitHub

`config/iasi-dev2/config-data/packages.toml` define el listado de programas Windows adicionales por identificador winget; actualmente vacío hasta elegir productos concretos. La etapa `packages` usa un ejecutor común. Si se declaran paquetes pero winget no está disponible en contexto SYSTEM, se detiene con error en lugar de omitirlos.

En `iasi-dev2/services` se mantiene el bootstrap concreto de Git y la operación `git` del repositorio de configuración. `setup-organization.ps1` descubre y sincroniza los repositorios **públicos** de `iasi-org-dev` con la API de GitHub (HTTPS, sin claves SSH ni login). La API anónima puede tener límites; un error detiene la preparación y conserva el trabajo previo.

## Estado de validación

TOML parseados con Python y ZIP comprobado. **No se han ejecutado las pruebas Hyper-V, PowerShell Direct, winget como SYSTEM ni las llamadas HTTPS de la VM.** El orquestador Linux todavía necesita verificación automática del sistema invitado; no se considera resuelto.
