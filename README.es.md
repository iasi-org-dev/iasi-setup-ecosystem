[🇬🇧 English](README.md) | [🇪🇸 **Español**](README.es.md)

# IASI Setup Ecosystem

`iasi-setup-ecosystem` es el punto de entrada para instalar y configurar el ecosistema IASI.

El repositorio reúne en un único lugar:

- la **Installation Guide**, materializable como web y PDF;
- los **binarios y scripts** necesarios para la instalación;
- las **configuraciones** de los componentes del ecosistema;
- las **licencias y avisos** que deben acompañar a la distribución.

## Inicio

```bash
git clone https://github.com/iasi-org/iasi-setup-ecosystem.git
cd iasi-setup-ecosystem
```

Windows:

```powershell
.\setup.ps1
```

Linux:

```bash
./setup.sh
```

El procedimiento completo se documenta en [`guide/`](guide/).

Este repositorio es todavía un **esqueleto de integración**. Los componentes de instalación ya se han probado individualmente; el siguiente paso de validación consiste en reproducir la instalación completa desde un entorno limpio utilizando únicamente este repositorio y su guía.

## Estructura del repositorio

- `bin/`: binarios y scripts de instalación y operación del ecosistema.
- `config/`: configuración de nodos, red y servicios.
- `guide/`: fuentes de la IASI Ecosystem Installation Guide.
- `setup.ps1` / `setup.sh`: puntos de entrada del bootstrap para el usuario.
- `LICENSES/`: licencias de terceros redistribuidas con el producto.

## Licencia

Licencia MIT. Consulte [`LICENSE`](LICENSE). Las licencias de terceros que deban acompañar a la distribución se mantienen en [`LICENSES/`](LICENSES/).
