#!/usr/bin/env bash

set -euo pipefail

SOURCE_ORG="iasi-org"
TARGET_ORG="iasi-org-dev"

SOURCE="/c/$SOURCE_ORG"
TARGET="/c/$TARGET_ORG"
TEMP="/c/temp"

# ---------------------------------------------------------------------------
# Comprobaciones
# ---------------------------------------------------------------------------

command -v git >/dev/null 2>&1 || {
    echo "ERROR: git no está disponible." >&2
    exit 1
}

command -v gh >/dev/null 2>&1 || {
    echo "ERROR: gh no está disponible." >&2
    exit 1
}

gh auth status >/dev/null 2>&1 || {
    echo "ERROR: GitHub CLI no está autenticado." >&2
    exit 1
}

if [ ! -d "$SOURCE" ]; then
    echo "ERROR: no existe $SOURCE" >&2
    exit 1
fi

if ! gh api "orgs/$TARGET_ORG" >/dev/null 2>&1; then
    echo "ERROR: no existe o no es accesible la organización $TARGET_ORG" >&2
    exit 1
fi

if [ -e "$TARGET" ]; then
    echo "ERROR: ya existe $TARGET" >&2
    echo "Este script es únicamente para crear inicialmente $TARGET_ORG." >&2
    exit 1
fi

mkdir -p "$TEMP"

# ---------------------------------------------------------------------------
# Obtener repositorios
#
# find incluye también .github
# ---------------------------------------------------------------------------

REPOSITORIES=()

while IFS= read -r -d '' repo; do
    if [ -e "$repo/.git" ]; then
        REPOSITORIES+=("$repo")
    fi
done < <(
    find "$SOURCE" \
        -mindepth 1 \
        -maxdepth 1 \
        -type d \
        -print0
)

if [ "${#REPOSITORIES[@]}" -eq 0 ]; then
    echo "ERROR: no se encontraron repositorios Git en $SOURCE" >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# Comprobar que todos los repositorios están limpios
# ---------------------------------------------------------------------------

for repo in "${REPOSITORIES[@]}"; do

    name="$(basename "$repo")"

    if [ -n "$(git -C "$repo" status --porcelain)" ]; then
        echo "ERROR: $name tiene cambios sin commit." >&2
        echo "Haz commit o limpia el repositorio antes del bootstrap." >&2
        exit 1
    fi

    if ! git -C "$repo" symbolic-ref --quiet HEAD >/dev/null; then
        echo "ERROR: $name está en detached HEAD." >&2
        exit 1
    fi

done

# ---------------------------------------------------------------------------
# Crear snapshots con historia nueva
# ---------------------------------------------------------------------------

for repo in "${REPOSITORIES[@]}"; do

    name="$(basename "$repo")"
    branch="$(git -C "$repo" symbolic-ref --short HEAD)"
    mirror="$TEMP/$name.git"

    echo
    echo "========================================"
    echo "$name"
    echo "========================================"

    # -----------------------------------------------------------------------
    # Mirror completo del origen.
    # El origen NO se modifica.
    # -----------------------------------------------------------------------

    if [ -d "$mirror" ]; then
        rm -rf "$mirror"
    fi

    echo "Creando mirror temporal..."
    git clone --mirror "$repo" "$mirror"

    source_head="$(git -C "$mirror" rev-parse HEAD)"
    tree="$(git -C "$mirror" rev-parse "${source_head}^{tree}")"

    # -----------------------------------------------------------------------
    # Crear un nuevo commit raíz con exactamente el contenido de HEAD.
    # No tiene padre.
    # -----------------------------------------------------------------------

    echo "Creando nuevo commit raíz..."

    root_commit="$(
        printf 'Bootstrap %s from %s\n\nSource commit: %s\n' \
            "$TARGET_ORG" \
            "$SOURCE_ORG" \
            "$source_head" |
        git -C "$mirror" commit-tree "$tree"
    )"

    # -----------------------------------------------------------------------
    # Eliminar todas las referencias antiguas DEL MIRROR.
    # -----------------------------------------------------------------------

    echo "Eliminando historia anterior del mirror..."

    while IFS= read -r ref; do
        git -C "$mirror" update-ref -d "$ref"
    done < <(
        git -C "$mirror" for-each-ref --format='%(refname)'
    )

    # Crear únicamente la rama actual apuntando al nuevo root.
    git -C "$mirror" update-ref "refs/heads/$branch" "$root_commit"
    git -C "$mirror" symbolic-ref HEAD "refs/heads/$branch"

    # Eliminar físicamente los commits antiguos del mirror.
    git -C "$mirror" reflog expire --expire=now --all
    git -C "$mirror" gc --prune=now

    # -----------------------------------------------------------------------
    # Crear repositorio destino si todavía no existe.
    # -----------------------------------------------------------------------

    if ! gh repo view "$TARGET_ORG/$name" >/dev/null 2>&1; then
        echo "Creando $TARGET_ORG/$name..."
        gh repo create "$TARGET_ORG/$name" --public
    fi

    # -----------------------------------------------------------------------
    # Publicar el snapshot.
    # -----------------------------------------------------------------------

    echo "Publicando..."

    git -C "$mirror" push \
        --mirror \
        "https://github.com/$TARGET_ORG/$name.git"

    gh repo edit \
        "$TARGET_ORG/$name" \
        --default-branch "$branch"

    echo "OK: $name"
done

# ---------------------------------------------------------------------------
# Clonar la nueva organización localmente
# ---------------------------------------------------------------------------

echo
echo "========================================"
echo "Clonando $TARGET_ORG en $TARGET"
echo "========================================"
echo

mkdir -p "$TARGET"

for repo in "${REPOSITORIES[@]}"; do

    name="$(basename "$repo")"

    echo "Clonando $name..."

    git clone \
        "https://github.com/$TARGET_ORG/$name.git" \
        "$TARGET/$name"

done

echo
echo "========================================"
echo "Bootstrap completado"
echo "========================================"
echo
echo "$SOURCE permanece intacto."
echo "$TARGET contiene la nueva línea de desarrollo."
echo "Los mirrors permanecen en $TEMP."