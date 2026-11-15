#!/bin/sh
# IASI GPU-P: activar en el Ubuntu definitivo las fuentes previamente staged.
# No modifica /opt/iasi/gpu ni instala un driver NVIDIA nativo de Linux.
set -eu
log() { printf '[IASI GPU] %s\n' "$*"; }
fail() { printf '[IASI GPU] ERROR: %s\n' "$*" >&2; exit 1; }
STAGE=/opt/iasi/gpu
DEST=/usr/lib/wsl
[ "$(id -u)" -eq 0 ] || fail 'Necesita root'
for d in drivers lib wsl; do [ -d "$STAGE/$d" ] || fail "Falta $STAGE/$d"; done
mkdir -p "$DEST/lib" "$DEST/drivers" /etc/ld.so.conf.d
# Conservar el nombre del paquete NVIDIA y sus directorios internos.
cp -a "$STAGE/drivers/." "$DEST/drivers/"
# WSL puede suministrar ficheros directamente o dentro de su subdirectorio lib/.
# Conservar todos los originales en /opt/iasi/gpu y copiar las bibliotecas Linux
# sin sobrescribir silenciosamente una biblioteca distinta.
copy_unique() {
  dir=$1
  [ -d "$dir" ] || return 0
  for f in "$dir"/*; do
    [ -f "$f" ] || [ -L "$f" ] || continue
    name=${f##*/}
    case "$name" in
      *.so|*.so.*|nvidia-smi) ;;
      *) continue ;;
    esac
    if [ -e "$DEST/lib/$name" ] || [ -L "$DEST/lib/$name" ]; then
      if cmp -s "$f" "$DEST/lib/$name"; then continue; fi
      fail "Colisión en $name entre fuentes; no se sobrescribe"
    fi
    cp -a "$f" "$DEST/lib/$name"
  done
}
# Preferir la copia procedente de WSL si ambas fuentes coinciden.
copy_unique "$STAGE/wsl"
copy_unique "$STAGE/wsl/lib"
copy_unique "$STAGE/lib"
# Aliases de compatibilidad: únicamente si no existe ya el nombre destino.
alias_if_missing() {
  src=$1; dest=$2
  if [ -e "$DEST/lib/$src" ] && [ ! -e "$DEST/lib/$dest" ] && [ ! -L "$DEST/lib/$dest" ]; then
    (cd "$DEST/lib" && ln -s "$src" "$dest")
  fi
}
alias_if_missing libd3d12core.so libD3D12Core.so
alias_if_missing libnvoptix.so.1 libnvoptix_loader.so.1
# libcuda.so.1 debe proceder preferentemente de la fuente original.
alias_if_missing libcuda.so libcuda.so.1
chown -R root:root "$DEST"
chmod -R a+rX "$DEST"
printf '%s\n' /usr/lib/wsl/lib > /etc/ld.so.conf.d/iasi-gpu.conf
ldconfig
log 'Bibliotecas y controladores preparados en /usr/lib/wsl.'
# No se instala el driver NVIDIA Linux; GPU-P usa dxgkrnl.
if ! command -v dkms >/dev/null 2>&1; then log 'DKMS no disponible; se requieren dependencias para dxgkrnl'; exit 1; fi
if [ ! -f /opt/iasi/dxgkrnl/install.sh ]; then fail 'Falta el instalador dxgkrnl'; fi
# Instalación contra el kernel actualmente arrancado. No usar -n: hace falta
# resolver las dependencias cuando no se han preparado previamente.
log 'Instalando dxgkrnl-dkms para el kernel actual...'
bash /opt/iasi/dxgkrnl/install.sh
modprobe dxgkrnl || log 'No se pudo cargar dxgkrnl; puede ser necesario reiniciar.'
if [ -e /dev/dxg ]; then
  log 'Detectado /dev/dxg'
else
  log 'ATENCIÓN: no existe /dev/dxg. Comprobar GPU-P en Hyper-V, DKMS y reinicio.'
fi
if [ -x "$DEST/lib/nvidia-smi" ]; then "$DEST/lib/nvidia-smi" || true
elif command -v nvidia-smi >/dev/null 2>&1; then nvidia-smi || true
else log 'nvidia-smi no disponible; consultar ldconfig -p y /dev/dxg'; fi
log 'GPU-P preparada; rendimiento y CUDA pendientes de prueba real.'
