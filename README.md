# IASI Setup Ecosystem

[Español](#español) · [English](#english)

`iasi-setup-ecosystem` forma parte de **IASI** y proporciona el punto de entrada para preparar un entorno desde el que desarrollar y trabajar con el ecosistema IASI.

`iasi-setup-ecosystem` is part of **IASI** and provides the entry point for preparing an environment from which to develop and work with the IASI ecosystem.

## Español

### Objetivo

Este proyecto reúne:

- una **guía de usuario** con el proceso de preparación del entorno;
- los **ejecutables de setup** para las plataformas soportadas;
- la base sobre la que se irá automatizando la instalación, configuración y materialización de los componentes necesarios del ecosistema IASI.

### Estructura

```text
iasi-setup-ecosystem/
├── bin/
│   ├── ps/
│   │   └── setup.ps1
│   └── sh/
│       └── setup.sh
├── docs/
│   └── user-guide/
│       ├── _quarto.yml
│       └── index.qmd
├── LICENSE
└── README.md
```

### Uso

#### Windows / PowerShell

```powershell
.\bin\ps\setup.ps1
```

#### Linux / shell

```bash
./bin/sh/setup.sh
```

Los scripts son, por ahora, el esqueleto mínimo del proceso de setup. Su funcionalidad crecerá junto con las necesidades del ecosistema IASI.

### Guía de usuario

La documentación se encuentra en [`docs/user-guide`](docs/user-guide/).

Para previsualizarla con Quarto:

```bash
quarto preview docs/user-guide
```

---

## English

### Purpose

This project contains:

- a **user guide** describing the environment setup process;
- the **setup executables** for supported platforms;
- the foundation for progressively automating the installation, configuration, and materialization of the components required by the IASI ecosystem.

### Structure

```text
iasi-setup-ecosystem/
├── bin/
│   ├── ps/
│   │   └── setup.ps1
│   └── sh/
│       └── setup.sh
├── docs/
│   └── user-guide/
│       ├── _quarto.yml
│       └── index.qmd
├── LICENSE
└── README.md
```

### Usage

#### Windows / PowerShell

```powershell
.\bin\ps\setup.ps1
```

#### Linux / shell

```bash
./bin/sh/setup.sh
```

For now, the scripts provide the minimal skeleton of the setup process. Their functionality will grow together with the needs of the IASI ecosystem.

### User guide

Documentation is located in [`docs/user-guide`](docs/user-guide/).

To preview it with Quarto:

```bash
quarto preview docs/user-guide
```

## License

MIT License. See [`LICENSE`](LICENSE).
