#!/usr/bin/env bash

set -e

SOURCE="/c/iasi-org"
TEMP="/c/temp"

TARGET_ORG="${1:?Uso: $0 <target-org>}"

for repo in "$SOURCE"/*; do

    [ -d "$repo/.git" ] || continue

    name=$(basename "$repo")

    echo
    echo "========================================"
    echo "$name"
    echo "========================================"

    mirror="$TEMP/$name.git"

    if [ -d "$mirror" ]; then
        git -C "$mirror" remote set-url origin "$repo"
        git -C "$mirror" remote update --prune
    else
        git clone --mirror "$repo" "$mirror"
    fi

    if ! gh repo view "$TARGET_ORG/$name" >/dev/null 2>&1; then
        gh repo create "$TARGET_ORG/$name" --public
    fi

    git -C "$mirror" push --mirror "https://github.com/$TARGET_ORG/$name.git"

done

echo
echo "IASI save completed: $SOURCE -> $TARGET_ORG"
echo "Los mirrors permanecen en $TEMP"

