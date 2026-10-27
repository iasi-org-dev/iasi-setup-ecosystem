IASI Models V1 - integrating common ports config
Extract to root of J:\iasi-setup-ecosystem preserving paths.
- config/ports.toml is shared across tools and models.
- User-provided services and Compose are configured from shared ports TOML.
- GPU selection and Hyper-V assignment come from the prior integration bundle.
- Ollama container is started with CPU configuration initially; guest NVIDIA support
  must be validated separately, followed by GPU runtime enablement.
- This bundle has NOT been tested on Windows PowerShell or Hyper-V.

Run from elevated PowerShell in repository root:
Get-ChildItem .\bin\ps -Filter *.ps1 -Recurse | Unblock-File
.\bin\ps\iasi-gpu-selection-test.ps1
.\bin\ps\hyper-v.ps1 --config .\config\iasi-models --path C:\Maquinas

No -f needed if VM does not yet exist.
