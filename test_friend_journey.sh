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
  PASS_C=0; FAIL_C=0
  pass_c() { echo "  PASS: $1"; PASS_C=$((PASS_C+1)); }
  fail_c() { echo "  FAIL: $1"; FAIL_C=$((FAIL_C+1)); }

  # Requires Winnow >= 0.9.5-core installed (has /start skill).
  # Check plugin version.
  PLUGIN_VER=$(python3 -c "
import json, pathlib, re
for base in [pathlib.Path.home() / '.claude/plugins/cache',
             pathlib.Path('/mnt/c/Users') / '$(whoami)' / '.claude/plugins/cache']:
    hits = list(base.glob('winnow-notes/winnow/*/'))
    if hits:
        latest = sorted(hits, key=lambda p: [int(x) if x.isdigit() else x for x in re.split(r'[-.]', p.name)])[-1]
        pf = latest / '.claude-plugin/plugin.json'
        if pf.exists():
            print(json.load(open(pf)).get('version','?'))
            exit()
print('not-found')
" 2>/dev/null || echo "not-found")
  echo "  Installed Winnow plugin: $PLUGIN_VER"
  if [[ "$PLUGIN_VER" == *"0.9.5"* ]] || [[ "$PLUGIN_VER" > "0.9.5" ]]; then
    pass_c "plugin version >= 0.9.5"
  else
    fail_c "plugin too old ($PLUGIN_VER) - run 'Check for updates' in Cowork then re-run"
    echo "  Skipping /start test."; FAIL_C=$((FAIL_C+1))
    echo ""; echo "Claude-dependent results: $PASS_C passed, $FAIL_C failed"; exit 1
  fi

  # Unzip a fresh vault for this test
  TMPVAULT=$(mktemp -d)
  trap "rm -rf '$TMPVAULT'" EXIT
  unzip -q "$ZIP" -d "$TMPVAULT"
  echo "  Test vault: $TMPVAULT"

  # Run /start with all scripted answers supplied upfront.
  # AskUserQuestion in -p mode does not block; answers must be in the initial prompt.
  START_PROMPT="Run /start for me. I will answer all the questions now so you can proceed without pausing.

My name is Alex. I am a product manager at a software company. I read technology news, product strategy articles, and history books - mostly about how technologies and organisations develop over time. What I want from Winnow: I want to remember and retrieve what I have read and thought. I do not use Readwise yet, so skip that step.

For the topic interview, here are my answers:

Topic 1 - technology and adoption: I think the standard narrative about tech adoption being driven by the best technology is mostly wrong. QWERTY, VHS vs Betamax, Windows vs Mac in the 90s - the pattern I keep coming back to is that distribution and timing beat product quality in almost every case. The exception might be safety-critical systems where you cannot afford the switching costs of a bad early choice.

Topic 2 - product strategy: The thing I disagree with most in product circles right now is the obsession with activation metrics. Everyone optimises for the first week and then wonders why retention is bad. My honest view is that the first week is almost irrelevant - what matters is whether the product builds a habit by week 6. I have seen this play out at two companies now.

Topic 3 - organisational development: I have been reading about how the Roman Republic transitioned into the Empire. What strikes me is that the institutions looked the same from the outside for about 50 years after they had effectively stopped working. The consuls kept being elected, the Senate kept meeting. It makes me suspicious of any organisation that is very proud of its processes - often the processes survive long after the purpose they served is gone.

Please save these as my interview transcript and proceed with the full /start flow: save the transcript, write the owner profile, write CLAUDE.md, build the index, and extract insights. Skip the Readwise step."

  set +e
  claude \
    --add-dir "$TMPVAULT" \
    -p "$START_PROMPT" \
    --output-format text \
    > /tmp/winnow-test-start-out-$$.txt \
    2> /tmp/winnow-test-start-err-$$.txt
  START_EC=$?
  set -e

  if [ "$START_EC" -eq 0 ]; then
    pass_c "/start claude invocation (exit 0)"
  else
    fail_c "/start claude invocation (exit $START_EC)"
    echo "  stderr tail:"; tail -20 /tmp/winnow-test-start-err-$$.txt || true
  fi
  rm -f /tmp/winnow-test-start-out-$$.txt /tmp/winnow-test-start-err-$$.txt

  # Outcome checks
  TRANSCRIPT=$(find "$TMPVAULT/Inbox" -name "Start - interview*.md" 2>/dev/null | head -1)
  [ -n "$TRANSCRIPT" ] && pass_c "interview transcript in Inbox/" || fail_c "interview transcript missing"

  python3 -c "
import json, sys
d = json.load(open('$TMPVAULT/winnow.json'))
ok = d.get('owner','') and d.get('owner') != 'friend' and d.get('setup_date')
sys.exit(0 if ok else 1)
" 2>/dev/null && pass_c "winnow.json updated (owner + setup_date)" || fail_c "winnow.json not updated"

  [ -f "$TMPVAULT/Winnow/owner-profile.md" ] && pass_c "owner-profile.md written" || fail_c "owner-profile.md missing"
  [ -f "$TMPVAULT/CLAUDE.md" ]               && pass_c "CLAUDE.md written" || fail_c "CLAUDE.md missing"

  CANDS=$(find "$TMPVAULT/Inbox/Candidates" -name "*.md" 2>/dev/null | wc -l)
  [ "$CANDS" -ge 5 ] && pass_c ">=5 candidates ($CANDS)" || fail_c "<5 candidates (got $CANDS)"

  echo ""
  echo "Claude-dependent results: $PASS_C passed, $FAIL_C failed"
  [ "$FAIL_C" -eq 0 ] || exit 1
else
  echo ""
  echo "Deterministic tests complete. Run with --with-claude for the full journey (Linux VM / Cowork)."
fi
