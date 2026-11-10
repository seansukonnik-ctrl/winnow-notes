#!/usr/bin/env bash
# Find the user's vault in every environment this plugin runs in.
# Prints the path on stdout, or exits 1 with a message on stderr.
#
# A vault is recognised by winnow.json in its root (written by /setup-vault),
# or, for vaults set up before that file existed, by resources/local-brain-search.

is_vault() {
  [ -f "$1/winnow.json" ] || [ -d "$1/resources/local-brain-search" ]
}

resolve_vault() {
  # 1. Explicitly configured, wins if it actually points at a real directory
  if [ -n "${VAULT_BASE_PATH:-}" ] && [ -d "$VAULT_BASE_PATH" ]; then
    printf '%s\n' "$VAULT_BASE_PATH"; return 0
  fi
  # 2. Cowork: connected folders mount under $HOME/mnt/ (newer) or /sessions/*/mnt/ (older)
  local d
  for d in "$HOME"/mnt/*/ /sessions/*/mnt/*/; do
    d="${d%/}"
    [ -d "$d" ] && is_vault "$d" && { printf '%s\n' "$d"; return 0; }
  done
  # 3. Launched inside the vault itself, or one level below it
  for d in "$PWD" "$(dirname "$PWD")"; do
    is_vault "$d" && { printf '%s\n' "$d"; return 0; }
  done
  echo "resolve-vault: no vault found. Looked for winnow.json (or resources/local-brain-search) in \$VAULT_BASE_PATH, the connected folders under \$HOME/mnt/, and the current directory. If the vault isn't set up yet, run /setup-vault." >&2
  return 1
}

resolve_vault
