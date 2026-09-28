[🇬🇧 **English**](README.md) | [🇪🇸 Español](README.es.md)

# IASI Setup Ecosystem

`iasi-setup-ecosystem` is the entry point for installing and configuring the IASI ecosystem.

The repository keeps together:

- the **Installation Guide**, materializable as web and PDF;
- the **binaries and scripts** required by the installation;
- the **configuration** of the ecosystem components;
- the **licenses and notices** that must travel with the distribution.

## Getting started

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

The complete procedure is documented in [`guide/`](guide/).

This repository is currently an **integration skeleton**. Its individual installation components have already been exercised separately; the next validation step is to reproduce the complete installation from a clean environment using only this repository and its guide.

## Repository layout

- `bin/`: installation and ecosystem binaries/scripts.
- `config/`: node, network and service configuration.
- `guide/`: IASI Ecosystem Installation Guide source.
- `setup.ps1` / `setup.sh`: human-facing bootstrap entry points.
- `LICENSES/`: third-party license material redistributed with the product.

## License

MIT License. See [`LICENSE`](LICENSE). Third-party license material belongs under [`LICENSES/`](LICENSES/).
