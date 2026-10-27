#!/usr/bin/env bash

# reset-git-history.sh
#
# Recreates the Git history of every repository found recursively from the
# current directory, including the current directory itself.
#
# A repository is identified by the presence of a `.git` directory.
#
# Intended use:
#   Keep iasi-org repositories as clean release snapshots while the complete
#   development history remains in iasi-org-dev.
#
# What it does for each repository:
#   1. Finds `.git` directories recursively from the current directory.
#   2. Does not descend into `.git` itself (`find ... -prune`).
#   3. Reads and preserves remote.origin.url.
#   4. Removes the existing local `.git` directory and its history.
#   5. Creates a new Git repository.
#   6. Uses `main` as the branch name.
#   7. Restores the original `origin`.
#   8. Adds the current working tree.
#   9. Creates one baseline commit representing the current repository state.
#  10. With `--push`, force-pushes the new `main` history to origin.
#
# Usage:
#
#   ./reset-git-history.sh
#
#       Rebuild local histories only.
#       Nothing is written to GitHub.
#
#   ./reset-git-history.sh --push
#
#       Rebuild local histories and replace origin/main with the new history.
#
# Examples:
#
#   cd /c/iasi-org
#   ./reset-git-history.sh
#
#   cd /c/iasi-org/iasi-home
#   ./reset-git-history.sh
#
# WARNING:
#   --push rewrites the remote main branch history.
#
# NOTE:
#   Repositories are discovered with:
#
#       find . -type d -name .git -prune
#
#   `-prune` means that when `find` encounters a `.git` directory, it reports
#   it but does not descend into its internal objects, refs, logs, etc.

set -euo pipefail

PUSH=false

case "${1:-}" in
  "")
    ;;
  --push)
    PUSH=true
    ;;
  *)
    echo "Usage: $0 [--push]"
    exit 1
    ;;
esac

while IFS= read -r gitdir; do
  repo="$(dirname "$gitdir")"

  echo
  echo "============================================================"
  echo "Repository: $repo"
  echo "============================================================"

  cd "$repo"

  origin="$(git remote get-url origin 2>/dev/null || true)"

  if [ -z "$origin" ]; then
    echo "No origin configured. Skipping."
    cd - >/dev/null
    continue
  fi

  echo "Origin: $origin"

  rm -rf .git

  git init
  git branch -M main
  git remote add origin "$origin"

  git add .
  git commit -m "Current IASI release baseline"

  if $PUSH; then
    echo "Replacing origin/main..."
    git push --force origin main
  else
    echo "Local history rebuilt. Remote unchanged."
  fi

  cd - >/dev/null

done < <(find . -type d -name .git -prune)

echo
echo "Done."
