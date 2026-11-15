#!/bin/sh
# IASI: conservar las tres fuentes GPU en el Ubuntu de destino.
# Se ejecuta durante la instalacion, desde la ISO seed.
set -eu

log() { printf '[IASI GPU] %s\n' "$*"; }
fail() { printf '[IASI GPU] ERROR: %s\n' "$*" >&2; exit 1; }

SOURCE=/mnt/iasi-seed/services/gpu
TARGET_ROOT=/target
DEST="$TARGET_ROOT/opt/iasi/gpu"

[ -d "$TARGET_ROOT/etc" ] || fail "Destino Ubuntu no valido: $TARGET_ROOT"
for folder in drivers lib wsl; do
    [ -d "$SOURCE/$folder" ] || fail "No existe $SOURCE/$folder"
    [ -n "$(ls -A "$SOURCE/$folder")" ] || fail "Carpeta vacia: $SOURCE/$folder"
done

log 'Copiando drivers, lib y wsl sin aplanar...'
mkdir -p "$DEST"
for folder in drivers lib wsl; do
    # Sustituimos cada carpeta staged, sin alterar las otras.
    rm -rf "$DEST/$folder"
    cp -a "$SOURCE/$folder" "$DEST/$folder"
    log "Preparada: $DEST/$folder"
done

log 'Fuentes copiadas. Sin instalar drivers ni crear enlaces simbolicos.'
