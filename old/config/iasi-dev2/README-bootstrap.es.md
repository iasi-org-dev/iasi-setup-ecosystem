# Bootstrap Windows IASI dev

Al crear la VM, `hyper-v.ps1` construye `%TEMP%\iasi\setup.iso` con `Autounattend.xml` y `iasi/bootstrap.ps1`.

En el primer inicio de sesión de la cuenta local `iasi`, Windows ejecuta el bootstrap: crea `Documents\PRJ\iasi-dev`, instala Git for Windows (incluye Git Bash) con `winget`, genera `%ProgramData%\IASI\drives.reg`, importa P: e I: y reinicia Windows inmediatamente al terminar.

Necesita Internet y `winget`. Ante un error no reinicia. Log: `%ProgramData%\IASI\bootstrap.log`. Para reintentar, ejecutar desde `setup.iso`: `powershell -ExecutionPolicy Bypass -File <unidad>:\iasi\bootstrap.ps1`.

Tras reiniciar, clonar manualmente `iasi-setup-ecosystem` y continuar con Stage 2.

Nota: el medio usa la cuenta de laboratorio iasi/iasi, contraseña visible en el XML.
