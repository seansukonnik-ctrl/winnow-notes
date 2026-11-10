#!/usr/bin/env bash
# End-to-end friend journey test for Winnow Notes.
#
# Usage:
#   bash test_friend_journey.sh                   # deterministic parts only (no Claude needed)
#   bash test_friend_journey.sh --with-claude     # + headless /start with a scripted fake friend
#
# --with-claude needs the claude CLI, logged in. It loads the plugin from this repo's plugins/winnow
# (--plugin-dir), so it tests what is about to be pushed, not what Cowork has cached. If the machine
# also has the full Winnow plugin installed at user level, both define /start with the same text,
# so the run is still valid. Takes 10-20 minutes and real API usage.
# Runs on Linux, macOS and Windows (Git Bash); paths handed to claude/python are converted with
# cygpath when it exists, because native Windows programs can't see Git Bash's /tmp.
set -euo pipefail

REPO=$(cd "$(dirname "$0")" && pwd)
ZIP="${WINNOW_ZIP:-$REPO/../Synced_PKM/resources/winnow-kit-dist/winnow-starter-vault.zip}"
native() { if command -v cygpath >/dev/null 2>&1; then cygpath -m "$1"; else printf '%s' "$1"; fi; }

if [ ! -f "$ZIP" ]; then
  echo "ERROR: starter vault zip not found at: $ZIP"
  echo "Build it first: cd <vault> && python3 resources/winnow-kit-src/build_starter_vault.py"
  exit 1
fi

# --- Deterministic tests ---
bash "$REPO/test_friend_journey_deterministic.sh" "$ZIP"

if [ "${1:-}" != "--with-claude" ]; then
  echo ""
  echo "Deterministic tests complete. Run with --with-claude for the full journey."
  exit 0
fi

echo ""
echo "=== Claude-dependent steps ==="
PASS_C=0; FAIL_C=0
pass_c() { echo "  PASS: $1"; PASS_C=$((PASS_C+1)); }
fail_c() { echo "  FAIL: $1"; FAIL_C=$((FAIL_C+1)); }

PLUGIN="$REPO/plugins/winnow"
PLUGIN_VER=$(python3 -c "import json,sys; print(json.load(open(sys.argv[1]))['version'])" "$(native "$PLUGIN/.claude-plugin/plugin.json")")
echo "  Plugin under test: $PLUGIN_VER ($PLUGIN)"
[ -f "$PLUGIN/skills/start/SKILL.md" ] && pass_c "plugin has /start" || { fail_c "plugin has no /start"; exit 1; }

# Fresh vault for this run; the log stays next to the repo so a failure can be read afterwards
TMPVAULT=$(mktemp -d)
trap 'rm -rf "$TMPVAULT"' EXIT
unzip -q "$ZIP" -d "$TMPVAULT"
VNATIVE=$(native "$TMPVAULT")
LOG="$REPO/.test-start-$(date +%Y%m%d-%H%M%S).log"
echo "  Test vault: $VNATIVE"
echo "  Log: $LOG"

# AskUserQuestion can't block in -p mode, so every answer is in the prompt.
# Alex is invented; same fake friend as the harness fixtures (make-friend-vault-fixtures.mjs).
START_PROMPT="Run /start for me. I will answer all the questions now so you can proceed without pausing.

My name is Alex. I am a product manager at a software company. I read technology news, product strategy articles, and history books - mostly about how technologies and organisations develop over time. What I want from Winnow: remember and retrieve what I have read and thought, and know what I actually think about a topic.

Readwise: I already have an account and I have connected the Readwise Official plugin in Obsidian (Connect, signed in, sync started). Treat my answer to that step as Connected.

For the topic interview, here are my answers:

Topic 1 - technology and adoption: I think the standard narrative about tech adoption being driven by the best technology is mostly wrong. QWERTY, VHS vs Betamax, Windows vs Mac in the 90s - the pattern I keep coming back to is that distribution and timing beat product quality in almost every case. The exception might be safety-critical systems where you cannot afford the switching costs of a bad early choice.

Topic 2 - product strategy: The thing I disagree with most in product circles right now is the obsession with activation metrics. Everyone optimises for the first week and then wonders why retention is bad. My honest view is that the first week is almost irrelevant - what matters is whether the product builds a habit by week 6. I have seen this play out at two companies now.

Topic 3 - organisational development: I have been reading about how the Roman Republic transitioned into the Empire. What strikes me is that the institutions looked the same from the outside for about 50 years after they had effectively stopped working. The consuls kept being elected, the Senate kept meeting. It makes me suspicious of any organisation that is very proud of its processes - often the processes survive long after the purpose they served is gone.

Please proceed with the full /start flow: save the transcript, write the owner profile, write CLAUDE.md, build the index, and extract insights."

set +e
( cd "$TMPVAULT" && VAULT_BASE_PATH="$VNATIVE" claude \
    --plugin-dir "$(native "$PLUGIN")" \
    --add-dir "$VNATIVE" \
    --allowedTools "Bash Read Write Edit Glob Grep Task Skill" \
    -p "$START_PROMPT" \
    --output-format text ) > "$LOG" 2>&1
START_EC=$?
set -e

[ "$START_EC" -eq 0 ] && pass_c "/start claude invocation (exit 0)" || { fail_c "/start claude invocation (exit $START_EC)"; tail -20 "$LOG" || true; }

TRANSCRIPT=$(find "$TMPVAULT/Inbox" -maxdepth 1 -name "Start - interview*.md" 2>/dev/null | head -1)
[ -n "$TRANSCRIPT" ] && pass_c "interview transcript in Inbox/" || fail_c "interview transcript missing"

python3 - "$VNATIVE/winnow.json" <<'PY' && pass_c "winnow.json: owner, setup_date, reading on, Guides excluded" || fail_c "winnow.json not calibrated"
import json, sys
d = json.load(open(sys.argv[1]))
assert d.get("owner") not in ("", None, "friend"), d.get("owner")
assert d.get("setup_date"), "setup_date"
assert "reading" in d.get("modules", []), d.get("modules")
assert "Guides" in d.get("index_exclude", []), d.get("index_exclude")
PY

[ -f "$TMPVAULT/Winnow/owner-profile.md" ] && pass_c "owner-profile.md written" || fail_c "owner-profile.md missing"
[ -f "$TMPVAULT/CLAUDE.md" ]               && pass_c "CLAUDE.md written" || fail_c "CLAUDE.md missing"

CANDS=$(find "$TMPVAULT/Inbox/Candidates" -maxdepth 1 -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
# One per interview topic at least; the extractor should not pad to hit a number.
[ "$CANDS" -ge 3 ] && pass_c ">=3 candidates, one per topic ($CANDS)" || fail_c "<3 candidates (got $CANDS)"

grep -q "| start |" "$TMPVAULT/Winnow/state.md" 2>/dev/null && pass_c "run log line in Winnow/state.md" || fail_c "no start line in Winnow/state.md"

echo ""
echo "Claude-dependent results: $PASS_C passed, $FAIL_C failed"
[ "$FAIL_C" -eq 0 ] || exit 1
