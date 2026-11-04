IASI integrated host bootstrap and VM identity - review build

Apply files by extracting the ZIP at the repository root, preserving paths.
This package contains changed files only; does not include or replace your VM service folders/GPU drivers.

Identity resolution: [identity] in config/setup.toml; optional [identity] section in each config/<machine>/config-data/config.toml, per-field override. WSL does not inherit it. Windows setup.toml retains [setup].profile only.

Commands (PowerShell as Administrator, from repo root):
  .\bin\ps\setup.ps1 --config .\config\hyperv.toml
  .\bin\ps\setup.ps1 --config .\config\wsl.toml
  .\bin\ps\setup.ps1 --config .\config\iasi-tools
  .\bin\ps\setup.ps1 --path C:\Maquinas

CAUTION: -f is destructive for selected VMs and network. Do not use it to test these changes on existing VMs.
WSL default is false in config/wsl.toml; if WSL instance IASI is different from your default distribution, current ISO generation (wsl.exe without -d) still uses the default. Set default = true explicitly once verified or adapt ISO tooling.
Existing VMs are unchanged; credentials apply to newly GENERATED media/recreated VMs.
WSL bootstrap may require restarting Windows; it must not unregister an existing distribution.
Security: config/setup.toml uses lab-only plaintext credentials; never use production secrets here. Windows answer ISO also contains a plaintext password.
QA: Static changes assembled from repository files. Windows/Hyper-V execution has NOT been validated. Review git diff and test each phase first.
