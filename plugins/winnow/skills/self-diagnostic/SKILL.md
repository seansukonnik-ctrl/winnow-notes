---
name: self-diagnostic
description: Check what is actually working in Winnow right now - index freshness, dependency health, count reconciliation, script drift - and write the result into the state file. Use at the start of a session, when something behaves oddly, or before setting the system up for someone else.
automation: manual
allowed-tools: Read, Write, Edit, Bash, Grep, Glob
user-invocable: true
---

# Winnow Self-Diagnostic

Checks facts, not file existence: whether the system currently does what it claims.

## Setup

Resolve the vault path once, before anything else. Do not glob for it by hand and do not assume `$VAULT_BASE_PATH` is set - it only exists when Claude Code is launched inside the vault, which is not the only place this plugin runs.

```bash
VAULT=$(bash "${CLAUDE_PLUGIN_ROOT}/scripts/resolve-vault.sh") || exit 1
WN_ENGINE="$VAULT/Winnow/search"; [ -d "$WN_ENGINE" ] || WN_ENGINE="$VAULT/resources/local-brain-search"
eval "$(python3 "$WN_ENGINE/winnow_env.py" "$VAULT")"   # folder names from winnow.json: $WN_PERMANENT, $WN_CANDIDATES, $WN_STATE ...
VAULT_BASE_PATH="$VAULT"
SCRIPT="$WN_SEARCH"
```

If the resolver fails, stop and say the vault could not be found - do not continue against a guessed path.

**READ-ONLY on vault content.** The only file it writes is `$WN_STATE`.

Runs in under a minute. If it takes longer, something is wrong and that is itself a finding.

---

## Checks

Each check has a pass condition. Anything that is not a pass is reported with its actual value, never as a generic "failed".

### 1. Index freshness

```bash
ls -la "$WN_ENGINE/data/embeddings.npy" "$WN_ENGINE/data/brain.faiss" 2>&1
ls "$WN_PERMANENT/"*.md | wc -l
```

- When was the index last written? Every build writes `embeddings.npy`; `brain.faiss` only when faiss is installed. Take the newer of the two.
- How many permanent notes exist now?
- How many notes in `$WN_PERMANENT/` are newer than that? That number is the index lag.

**Pass:** lag is 0 and the rebuild is under 48 hours old.
**Report as:** `index rebuilt [date], N notes behind`.

### 2. Learning layer is alive

```bash
ls -la "$WN_ENGINE/data/q_values.json"
ls -la "$WN_ENGINE/data/usage_history.jsonl"
wc -l "$WN_ENGINE/data/usage_history.jsonl"
```

CLAUDE.md claims Usage-Based Learning is Active. If these files have not been written in weeks, the claim is false and the whole SYNAPSE layer is dormant regardless of index state.

**Pass:** both written within the last 7 days.

### 3. Dependencies actually import

Do not check whether a venv folder exists - check whether the thing imports.

```bash
python3 -c "import rank_bm25; print('rank_bm25 ok')" 2>&1 | tail -1
python3 -c "import faiss; print('faiss ok')" 2>&1 | tail -1
python3 -c "import torch; print('torch', torch.__version__)" 2>&1 | tail -1
python3 -c "import sentence_transformers; print('st ok')" 2>&1 | tail -1
python3 -c "import onnxruntime, tokenizers; print('onnx ok')" 2>&1 | tail -1
```

Search and index builds both run on either path: torch + sentence-transformers (the Windows venv), or the ONNX export (onnxruntime + tokenizers). So `onnx ok` or `st ok` is enough; faiss is optional everywhere.

Report each as ok or with the actual error line. `torch` failing on `shm.dll` is the known Windows native-DLL problem and should be named as such, not as "torch missing".

### 4. Which search backend is running here

```bash
bash "$SCRIPT" backend
```

`semantic` means embeddings over the prebuilt index (0-1 similarity scores) - through torch + faiss on Windows, through the ONNX export in the Cowork sandbox; same results either way. `keyword` means the BM25 last resort: raw scores, no semantic edges, no spreading activation, no learning. Every similarity threshold in the skills assumes `semantic`.

**Pass:** `semantic`, in any environment. `keyword` means the ONNX deps (onnxruntime, tokenizers, numpy>=2, networkx) could not be installed or `onnx_model/` / `data/embeddings.npy` is missing - report it red with the reason from stderr.

### 5. Queue ages

```bash
ls -la "$WN_CANDIDATES/"*.md 2>/dev/null | wc -l
find "$WN_CANDIDATES/" -name "*.md" -mtime +14 -print0 2>/dev/null | xargs -0 -r ls -la
```

- How many candidates are waiting?
- How many have been waiting more than 14 days?

A growing queue is a signal, not an achievement. Report the old ones by name - they are usually old because a decision was avoided, not because they were missed.

### 6. Unprocessed intake

Run the same discovery as `process-new-notes` Step 1, null-delimited, and report the count only. Tells you whether there is a backlog before you go looking for one.

### 7. Deletion

```bash
T="$WN_SYSTEM/.diag-probe"
touch "$T" && rm "$T" 2>&1 && echo "delete: ok" || echo "delete: BLOCKED"
```

Deletion blocked is the known device-bridge restriction - if it is blocked, note that `device_request_delete_permission` has not been tried yet.

### 8. Documentation that contradicts reality

- Does `CLAUDE.md` describe a component as working while a check above says otherwise?
- Does the vault still hold a `.claude/skills/` copy of a skill that this plugin also ships (two copies that can disagree)?
- If there are several voice profiles (`*voice_profile_v*.md`), are the older versions still sitting next to the newest?

Each of these is a trap for whoever reads the docs and believes them, including the agent itself.

---

## Output

Short. One line per check.

```
## Self-Diagnostic - YYYY-MM-DD

✓ index          rebuilt 2026-09-30 11:55, 0 notes behind
✗ learning       q_values unchanged since 2026-08-12 (49 days) - learning layer asleep
✓ onnx           ok
✓ backend        semantic
✓ queue          12 candidates, older than 2 weeks: 0
✓ intake         nothing unprocessed
✗ delete         BLOCKED - device_request_delete_permission not tried yet
✗ docs           CLAUDE.md says learning is active (it isn't)

Red: 3. Details and what to do about them - $WN_STATE
```

Then update `$WN_STATE`:

- refresh every row of **Live metrics** this run actually measured, with today's date in "Checked"
- rewrite **Red** to match what this run found. Remove an item only when a check passed, never because it was discussed
- move anything that recovered from **Red** to **Yellow** or out entirely
- append one line to **Run log**

## Rule

Never report a check as passing because the thing it checks is supposed to work. If a check cannot run - the shell is unavailable, a path is unreachable - report it as `? not checked` and say why. `?` is an honest result; a green tick over an unrun check is the failure mode this skill was rewritten to fix.
