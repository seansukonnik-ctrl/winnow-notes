#!/usr/bin/env bash
# Rebuild the Winnow core edition from the vault and copy it into plugins/winnow.
# Usage: ./publish.sh [vault path]   (default: $WINNOW_VAULT or the usual vault)
set -euo pipefail
cd "$(dirname "$0")"
VAULT="${1:-${WINNOW_VAULT:-../Synced_PKM}}"
SRC="$VAULT/resources/winnow-plugin/src"
PY=$(command -v python3 || command -v python)

"$PY" "$SRC/build.py"
VERSION=$(tr -d '[:space:]' < "$SRC/VERSION")
ZIP="$VAULT/resources/winnow-plugin/dist/winnow-$VERSION-core.plugin"

STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT
unzip -q "$ZIP" -d "$STAGE"

# Privacy guard: refuse obvious personal strings. Extend the pattern, never remove it.
# The vault folder name and the OS user name are added at run time so they never sit in this repo.
VNAME=$(basename "$(cd "$VAULT" && pwd)")
ME="${USER:-${USERNAME:-$VNAME}}"
if grep -rIn -i -E "$VNAME|$ME|[A-Z]:[\]Users[\]|/Users/[^/]+/|@gmail[.]com" "$STAGE"; then
  echo "publish: personal strings found in the build (above). Fix the source in the vault." >&2
  exit 1
fi

rm -rf plugins/winnow
mkdir -p plugins
cp -R "$STAGE" plugins/winnow
cp LICENSE plugins/winnow/LICENSE
echo "publish: plugins/winnow is now $(grep -o '"version": *"[^"]*"' plugins/winnow/.claude-plugin/plugin.json)"
echo "Review with 'git status', then commit and push."
