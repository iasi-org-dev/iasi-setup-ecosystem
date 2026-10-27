#!/bin/sh
# IASI-Models: first boot provisioning. Runs as root from cloud-init.
set -eu
log() { printf '[IASI BOOT] %s\n' "$*"; }
fail() { printf '[IASI BOOT] ERROR: %s\n' "$*" >&2; exit 1; }
[ "$(id -u)" -eq 0 ] || fail 'Requires root'
[ -f /opt/iasi/activate-gpu.sh ] || fail 'Missing activate-gpu.sh'
log 'Activating GPU-P...'
/bin/bash /opt/iasi/activate-gpu.sh
[ -e /dev/dxg ] || fail '/dev/dxg is missing; IASI-Models not started'
# nvidia-smi is placed with the staged WSL user-mode libraries; demand real command success.
if [ -x /usr/lib/wsl/lib/nvidia-smi ]; then
    /usr/lib/wsl/lib/nvidia-smi || fail 'nvidia-smi failed; IASI-Models not started'
elif command -v nvidia-smi >/dev/null 2>&1; then
    nvidia-smi || fail 'nvidia-smi failed; IASI-Models not started'
else
    fail 'nvidia-smi is not installed; IASI-Models not started'
fi
log 'GPU-P verified. Starting Docker...'
systemctl start docker
[ -f /opt/iasi/iasi-models-compose.yml ] || fail 'Missing compose file'
[ -f /opt/iasi/iasi-services.env ] || fail 'Missing env file'
docker compose --env-file /opt/iasi/iasi-services.env -f /opt/iasi/iasi-models-compose.yml up -d
log 'IASI-Models services started.'
