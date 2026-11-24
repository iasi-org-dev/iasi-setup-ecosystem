#!/bin/sh
# IASI-Models: NVIDIA Container Toolkit for Docker (Ubuntu/Debian).
# Re-runnable. Must execute AFTER GPU-P activation and BEFORE Docker Compose.
set -eu
log() { printf '[IASI NVIDIA CONTAINER] %s\n' "$*"; }
fail() { printf '[IASI NVIDIA CONTAINER] ERROR: %s\n' "$*" >&2; exit 1; }
[ "$(id -u)" -eq 0 ] || fail 'Run as root'
command -v docker >/dev/null 2>&1 || fail 'Docker must be installed first'
[ -e /dev/dxg ] || fail '/dev/dxg unavailable: activate GPU-P first'

if ! command -v nvidia-ctk >/dev/null 2>&1; then
    log 'Installing NVIDIA Container Toolkit...'
    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get install -y --no-install-recommends ca-certificates curl gnupg
    install -d -m 0755 /usr/share/keyrings /etc/apt/sources.list.d
    curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | gpg --batch --yes --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
    curl -fsSL https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list \
      | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' \
      > /etc/apt/sources.list.d/nvidia-container-toolkit.list
    apt-get update
    apt-get install -y --no-install-recommends nvidia-container-toolkit
else
    log 'NVIDIA Container Toolkit already installed; preserving installed version.'
fi

command -v nvidia-container-cli >/dev/null 2>&1 || fail 'nvidia-container-cli is missing'
log 'Checking NVIDIA userspace access...'
nvidia-container-cli info >/dev/null || fail 'NVIDIA access check failed'

# Only rewrite Docker configuration/restart daemon if runtime is not registered.
if ! docker info --format '{{range $name, $runtime := .Runtimes}}{{println $name}}{{end}}' 2>/dev/null | grep -qx nvidia; then
    log 'Configuring NVIDIA runtime for Docker...'
    nvidia-ctk runtime configure --runtime=docker
    systemctl restart docker
else
    log 'NVIDIA runtime already registered; not restarting Docker.'
fi

# A daemon start can also be needed when Docker was previously stopped.
systemctl start docker
if ! docker info --format '{{range $name, $runtime := .Runtimes}}{{println $name}}{{end}}' | grep -qx nvidia; then
    fail 'NVIDIA runtime not registered in Docker'
fi
log 'NVIDIA Container Toolkit ready.'
