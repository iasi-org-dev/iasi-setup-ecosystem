IASI-Models integrated deployment

1. gpu.ps1 collects drivers/lib/wsl on Windows.
2. ISO includes GPU sources and services scripts.
3. Installer stages sources in /opt/iasi/gpu and installs Docker as configured elsewhere.
4. On first Ubuntu boot cloud-init invokes /opt/iasi/iasi-deploy-start.sh.
5. Script activates GPU-P, requires /dev/dxg and nvidia-smi, then starts Docker and compose.
6. Failure: check cloud-init logs and run sudo sh /opt/iasi/iasi-deploy-start.sh after correction.

No automatic reboot. Actual Legion execution is still to be verified.
