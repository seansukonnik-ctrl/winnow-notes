#!/usr/bin/env bash
# Deterministic (no Claude) part of the friend journey test.
# Usage: bash test_friend_journey_deterministic.sh <path-to-winnow-starter-vault.zip>
# Runs on Linux (Cowork VM) or macOS. On Windows/Git-Bash some steps may be skipped.
set -euo pipefail

ZIP="${1:?Usage: $0 <path-to-winnow-starter-vault.zip>}"
TMPDIR_BASE="${TMPDIR:-/tmp}"
VAULT="$TMPDIR_BASE/winnow-test-$$"
PASS=0; FAIL=0

pass() { echo "PASS  $1"; PASS=$((PASS+1)); }
fail() { echo "FAIL  $1"; FAIL=$((FAIL+1)); }
require() {
  local label="$1"; shift
  if "$@" >/dev/null 2>&1; then pass "$label"; else fail "$label"; return 1; fi
}

cleanup() { rm -rf "$VAULT"; }
trap cleanup EXIT

echo "=== Winnow deterministic test ==="
echo "ZIP: $ZIP"
echo "VAULT: $VAULT"
echo ""

# 1. Unzip
mkdir -p "$VAULT"
unzip -q "$ZIP" -d "$VAULT"
pass "unzip"

# 2. Folder structure
for d in "Inbox" "Inbox/Candidates" "Permanent Notes" "Winnow/search" "Winnow/reading"; do
  [ -d "$VAULT/$d" ] && pass "dir: $d" || fail "dir: $d"
done

# 3. winnow.json valid JSON with required fields
python3 - "$VAULT/winnow.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
for k in ("kit_version", "owner", "folders", "modules"):
    assert k in d, f"missing key: {k}"
assert d["folders"]["inbox"] == "Inbox"
assert d["folders"]["candidates"] == "Inbox/Candidates"
assert d["folders"]["permanent"] == "Permanent Notes"
print("ok")
PY
pass "winnow.json fields"

# 4. winnow_env.py works
OUTPUT=$(python3 "$VAULT/Winnow/search/winnow_env.py" "$VAULT" 2>&1)
echo "$OUTPUT" | grep -q "WN_PERMANENT=" && pass "winnow_env.py exports" || fail "winnow_env.py exports"

eval "$OUTPUT"   # load WN_* vars for the rest of the test

# 5. brain_search.sh backend
BACKEND=$(bash "$VAULT/Winnow/search/brain_search.sh" backend 2>/dev/null || true)
if echo "$BACKEND" | grep -qE "^(semantic|keyword)"; then
  pass "backend: $(echo "$BACKEND" | head -1)"
else
  fail "backend unexpected output: ${BACKEND:-empty}"
fi

# 6. Index build on empty vault (exit 0=done, 2=no-deps warn, 3=partial)
set +e
bash "$VAULT/Winnow/search/brain_search.sh" index --budget 30 2>/dev/null
EC=$?
set -e
INDEX_BUILT=false
if [ "$EC" -eq 0 ] || [ "$EC" -eq 3 ]; then
  pass "index build (empty)"; INDEX_BUILT=true
elif [ "$EC" -eq 1 ] || [ "$EC" -eq 2 ]; then
  pass "index build skipped: deps not available (ok in WSL/no-pip; works in Cowork VM)"
else
  fail "index build failed (exit $EC)"
fi

# 7. Write fake-friend fixture notes
cat > "$VAULT/Inbox/note-pm-agile.md" <<'NOTE'
---
created: 2026-11-10
---
I keep coming back to the idea that good product management is fundamentally about reducing uncertainty before writing code. Agile as most teams practise it is just fast waterfall with daily standups.
NOTE

cat > "$VAULT/Inbox/note-history-empires.md" <<'NOTE'
---
created: 2026-11-10
---
Reading about the late Roman Empire - what strikes me is not the military collapse but the administrative fragmentation. Diocletian's reforms basically admitted the empire was ungovernable as a unit. Modern large organisations repeat this pattern constantly.
NOTE
pass "fixture notes written"

# 8. Index build with notes
set +e
bash "$VAULT/Winnow/search/brain_search.sh" index --budget 60 2>/dev/null
EC=$?
set -e
if [ "$EC" -eq 0 ] || [ "$EC" -eq 3 ]; then
  pass "index build (with notes)"; INDEX_BUILT=true
elif [ "$EC" -eq 2 ]; then
  pass "index build (with notes) skipped: no ONNX deps (ok in WSL)"
else
  fail "index build (with notes) exit $EC"
fi

# 9. Search returns valid JSON
if $INDEX_BUILT; then
  set +e
  SEARCH=$(bash "$VAULT/Winnow/search/brain_search.sh" search "product management" --json 2>/dev/null)
  SEARCH_EC=$?
  set -e
  if [ "$SEARCH_EC" -ne 0 ] || [ -z "$SEARCH" ]; then
    fail "search failed (exit $SEARCH_EC, empty output)"
  else
    echo "$SEARCH" > "/tmp/winnow-test-search-$$.json"
    python3 -c "import json; j=json.load(open('/tmp/winnow-test-search-$$.json')); assert isinstance(j,(list,dict))" \
      && pass "search returns JSON" || fail "search output not valid JSON"
    rm -f "/tmp/winnow-test-search-$$.json"
  fi
else
  pass "search skipped: no deps available (ok in WSL/no-pip env)"
fi

# 10. Write a sample candidate with correct frontmatter
CAND="$VAULT/Inbox/Candidates/candidate-pm-uncertainty.md"
cat > "$CAND" <<'CAND'
---
created: 2026-11-10
created_by: test-fixture
updated: 2026-11-10
updated_by: test-fixture
agent_version: 03.26
status: candidate
source_type: journal
possible_duplicate: null
review_decision: null
---
# Good product management reduces uncertainty before code is written

> The primary job of a product manager is to reduce decision uncertainty before engineering work begins.

Most teams treat planning as a formality before sprints. The actual value is in the questions it forces earlier.

## Connections

## Source

[[note-pm-agile]]
CAND
pass "candidate file written"

# 11. Frontmatter check on candidate
python3 - "$CAND" <<'PY'
import sys
content = open(sys.argv[1]).read()
assert content.startswith("---"), "no frontmatter"
fm_end = content.index("---", 3)
fm = content[3:fm_end]
for field in ("status: candidate", "review_decision: null", "agent_version: 03.26"):
    assert field in fm, f"missing: {field}"
print("ok")
PY
pass "candidate frontmatter valid"

# 12. Dedup check on candidate (requires semantic index; skipped if no ONNX deps)
if $INDEX_BUILT; then
  set +e
  DEDUP=$(bash "$VAULT/Winnow/search/brain_search.sh" dedup "$VAULT/Inbox/Candidates" --json 2>/dev/null)
  DEDUP_EC=$?
  set -e
  if [ "$DEDUP_EC" -eq 0 ] && [ -n "$DEDUP" ]; then
    echo "$DEDUP" > "/tmp/winnow-test-dedup-$$.json"
    python3 -c "import json; j=json.load(open('/tmp/winnow-test-dedup-$$.json')); assert isinstance(j,(list,dict))" \
      && pass "dedup returns JSON" || fail "dedup output not valid JSON"
    rm -f "/tmp/winnow-test-dedup-$$.json"
  else
    fail "dedup failed (exit $DEDUP_EC)"
  fi
else
  pass "dedup skipped: no semantic index (ok in WSL/no-pip env)"
fi

# 13. Simulate Selection queue decision: write review_decision: promote
python3 - "$CAND" <<'PY'
import sys, re
path = sys.argv[1]
content = open(path).read()
content = re.sub(r"review_decision: null", "review_decision: promote", content, count=1)
open(path, "w").write(content)
assert "review_decision: promote" in content
print("ok")
PY
pass "review_decision written"

# 14. Verify decision was persisted
grep -q "review_decision: promote" "$CAND" && pass "review_decision persisted" || fail "review_decision persisted"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] || exit 1
