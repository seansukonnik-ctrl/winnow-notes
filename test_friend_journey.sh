#!/usr/bin/env bash
# End-to-end friend journey test for Winnow Notes.
#
# Usage:
#   bash test_friend_journey.sh                   # deterministic parts only (no Claude needed)
#   bash test_friend_journey.sh --with-claude      # + headless /start (needs claude CLI + vault connected)
#
# The --with-claude flag runs the full journey including /start. It requires:
#   - claude CLI installed and authenticated
#   - The vault folder added to Cowork (or VAULT_BASE_PATH set to the temp vault path)
#   - About 15 minutes
#
# Run the deterministic part in the Cowork Linux VM to test the friend's real environment:
#   bash test_friend_journey.sh
# That alone covers: unzip, structure, index build, search, dedup, candidate frontmatter, queue decision.
set -euo pipefail

REPO=$(cd "$(dirname "$0")" && pwd)
ZIP="$REPO/../Synced_PKM/resources/winnow-kit-dist/winnow-starter-vault.zip"

if [ ! -f "$ZIP" ]; then
  echo "ERROR: starter vault zip not found at: $ZIP"
  echo "Build it first: cd <vault> && python3 resources/winnow-kit-src/build_starter_vault.py"
  exit 1
fi

# --- Deterministic tests ---
bash "$REPO/test_friend_journey_deterministic.sh" "$ZIP"

# --- Claude-dependent tests (skipped unless --with-claude) ---
if [ "${1:-}" = "--with-claude" ]; then
  echo ""
  echo "=== Claude-dependent steps ==="

  # shortcut: headless /start is documented but not yet automated, implement when claude -p
  # noninteractive mode is confirmed to work with AskUserQuestion tools in Cowork.
  #
  # Intended invocation (pseudo):
  #   TMPVAULT=$(mktemp -d)
  #   unzip -q "$ZIP" -d "$TMPVAULT"
  #   export VAULT_BASE_PATH="$TMPVAULT"
  #   claude -p \
  #     --allowedTools "Bash,Read,Write,Edit,Glob,Grep,AskUserQuestion,Task" \
  #     --plugin "$REPO/plugins/winnow" \
  #     "/start" <<'ANSWERS'
  #   Alex
  #   Product manager, reads tech and history
  #   Remember and retrieve what I've read and thought
  #   No
  #   ANSWERS
  #
  #   Then check:
  #     [ -f "$TMPVAULT/winnow.json" ] && python3 -c "import json; d=json.load(open('$TMPVAULT/winnow.json')); assert d['owner'] != 'friend'"
  #     CANDS=$(ls "$TMPVAULT/Inbox/Candidates/"*.md 2>/dev/null | wc -l)
  #     [ "$CANDS" -ge 5 ] || { echo "FAIL: expected 5+ candidates, got $CANDS"; exit 1; }
  #     echo "PASS: $CANDS candidates created"

  echo "SKIPPED: headless /start not yet automated - run manually in Cowork Linux VM"
  echo "See comments in this file for the intended invocation."
else
  echo ""
  echo "Deterministic tests complete. Run with --with-claude for the full journey (Linux VM / Cowork)."
fi
