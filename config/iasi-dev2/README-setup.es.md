# Medio auxiliar de instalacion Windows (iasi-dev2)

Al ejecutar `hyper-v.ps1 --config .\config\iasi-dev2 --path C:\Maquinas -f`, la herramienta valida `xorriso` en la distribucion WSL predeterminada y genera, bajo `%TEMP%\iasi\iasi-dev2`, dos archivos temporales: `os.iso` (copia de `$SourceISO`) y `setup.iso` (ISO auxiliar nueva).

El segundo DVD contiene `Autounattend.xml` con una cuenta de administrador local. Cambia `config-data/90-setup.ps1` para modificar el perfil o las credenciales **antes de crear** la VM. La instalacion del sistema operativo continua siendo interactiva; comprobar que Windows Setup detecta las respuestas desde el segundo DVD.

**Advertencia**: `setup.iso` incluye la contrasena en texto claro. Usar solo en laboratorios aislados. Ni Windows ni IASI garantizan la limpieza automatica de `%TEMP%`; no eliminar los medios mientras sigan montados en Hyper-V. Una reconstruccion con `-f` elimina la VM existente.
