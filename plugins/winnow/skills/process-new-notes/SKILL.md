---
name: process-new-notes
description: Routine intake for new notes. Finds unprocessed notes in the Inbox (recursive) and the other intake folders set in winnow.json, stamps them, refreshes the search index and extracts insight candidates into the candidate queue for the Selection queue. Verifies its own arithmetic and never reports success on a mismatch.
allowed-tools:
- Read
- Write
- Edit
- Bash
- Glob
- Grep
- AskUserQuestion
- Task
user-invocable: true
---

# Process New Notes

Full intake pipeline: discover, stamp, index, extract candidates, move, **verify**.

## What This Skill Does

The user writes their own raw thinking in `$WN_INBOX/` (in any subfolders) and in the extra intake folders listed in `winnow.json`. Some vaults also define reading flows of their own in `winnow.json` `folders`: `new_notes` and `quickreads` (articles read and annotated, moved to `analysed` once processed) and `essays` (long-form reading notes, stamped in place). **Those three exist only when `winnow.json` names them** - if `$WN_NEW_NOTES`, `$WN_QUICKREADS` or `$WN_ESSAYS` is empty, that source is "not present": skip every command that uses it (an empty variable would turn `"$WN_ESSAYS/"` into `/`). The owner's published writing is never touched. This skill processes all intake sources in one pass:

0. **Read state** from `$WN_STATE`
1. **Discover** unprocessed files across four locations, and **record the count**
2. **Stamp frontmatter** with `status: indexed` and metadata
3. **Refresh the index** so new files are searchable
4. **Extract insight candidates** via `insight-extractor` → `$WN_CANDIDATES/`
5. **Move** New Notes and Quickreads to `$WN_ANALYSED/` (essays and inbox notes never move)
6. **Verify** the arithmetic - discovered must equal processed plus explicitly-skipped
7. **Report and write back to state**

## Source Locations

| Location | What lands here | After processing |
|----------|-----------------|-----------------|
| `$WN_INBOX/` (recursive) | The user's own raw thinking, in their own subfolders | Stamp in place, never move |
| extra intake folders (`winnow.json` `intake`) | Wherever else their own thinking lives | Stamp in place, never move |
| `$WN_NEW_NOTES/` (only if defined) | Articles the user read and took notes on | Move to `$WN_ANALYSED/` |
| `$WN_QUICKREADS/` (only if defined) | Short reads | Move to `$WN_ANALYSED/` |
| `$WN_ESSAYS/` (only if defined) | The user's analysis of other people's long-form essays | Stamp in place, never move |

`$WN_CANDIDATES/` is this skill's OUTPUT folder and must be excluded from discovery, or the skill will eat its own candidates.

**Why Essays and $WN_INBOX are stamped in place while New Notes and Quickreads move.** It is not about authorship - all three sources are the user's own analysis of things they read. It is about how "already processed" is marked. New Notes and Quickreads carry no status field, so the move into `Analysed pieces/` IS the marker; without it the skill could not tell a processed file from a fresh one. Essays and Inbox notes carry `status: indexed` in frontmatter instead, so the folder works as queue and library at once - unprocessed files are found by the filter, processed ones sit alongside harmlessly. Moving them would gain nothing and would strand every `## Source` line in `$WN_PERMANENT/` that cites an `$WN_ESSAYS/...` path, of which there are dozens.

---

## Process

## Setup

```bash
VAULT=$(bash "${CLAUDE_PLUGIN_ROOT}/scripts/resolve-vault.sh") || exit 1
WN_ENGINE="$VAULT/Winnow/search"; [ -d "$WN_ENGINE" ] || WN_ENGINE="$VAULT/resources/local-brain-search"
eval "$(python3 "$WN_ENGINE/winnow_env.py" "$VAULT")"   # folder names from winnow.json: $WN_PERMANENT, $WN_CANDIDATES, $WN_STATE ...
VAULT_BASE_PATH="$VAULT"
SCRIPT="$WN_SEARCH"
```

If the resolver fails, stop and say the vault could not be found.

### Step 0: Read State

Read `$WN_STATE`. If anything sits under "Red" that affects this run (index rebuild broken, deletion blocked), say so before starting rather than after failing.

### Step 1: Discover Files

**CRITICAL - null-delimited only.** Filenames in this vault contain spaces almost always. A plain `find ... | xargs` word-splits on whitespace, the lookup silently fails, and the skill reports success having processed nothing. Never use bare `xargs` here.

**$WN_INBOX, recursive, excluding the skill's own output folder:**
```bash
find "$WN_INBOX/" -name "*.md" -not -path "$WN_CANDIDATES/*" -print0 \
  | xargs -0 grep -L "indexed_date" 2>/dev/null
```

**New Notes and Quickreads (only if defined) - all .md files (no filter):**
```bash
[ -n "$WN_NEW_NOTES" ] && ls "$WN_NEW_NOTES/"*.md 2>/dev/null
[ -n "$WN_QUICKREADS" ] && ls "$WN_QUICKREADS/"*.md 2>/dev/null
```

**Essays (only if defined) - only files missing `status: indexed`:**
```bash
[ -n "$WN_ESSAYS" ] && grep -rL "status: indexed" "$WN_ESSAYS/" --include="*.md" 2>/dev/null
```

**Extra intake folders** - folders listed under `intake` in `winnow.json` (set up by `/setup-vault` for users whose notes live outside $WN_INBOX). Treated like $WN_INBOX: recursive, only files without `indexed_date`, stamped in place, never moved. If `intake_since` is set, files last modified before that date are the pre-setup backlog and are left alone (the user works through the backlog on request, not in the routine run):
```bash
python3 - "$VAULT_BASE_PATH" <<'PY'
import json, os, sys, datetime
vault = sys.argv[1]
try:
    cfg = json.load(open(os.path.join(vault, "winnow.json"), encoding="utf-8"))
except FileNotFoundError:
    sys.exit(0)
since = cfg.get("intake_since")
cut = datetime.datetime.fromisoformat(since).timestamp() if since else 0
for folder in cfg.get("intake", []):
    for root, dirs, files in os.walk(os.path.join(vault, folder)):
        if os.path.abspath(root).startswith(os.path.abspath(os.environ.get("WN_CANDIDATES", "/nonexistent"))):
            continue
        for f in files:
            p = os.path.join(root, f)
            if f.endswith(".md") and os.path.getmtime(p) >= cut:
                with open(p, encoding="utf-8", errors="replace") as fh:
                    if "indexed_date" not in fh.read():
                        print(p)
PY
```

Sources that don't exist in this vault (most vaults define no `new_notes`, `quickreads` or `essays`) are reported as "not present", not as zero.

**Record `DISCOVERED_TOTAL` and the per-source counts now, before doing anything else.** These numbers are what Step 6 checks against. Write the full list of discovered paths down - Step 6 needs the names, not just the count.

If nothing found anywhere, report and stop.

### Step 2: Stamp Frontmatter

For every discovered file, stamp the following. Do NOT overwrite existing `created` or `created_by`.

```yaml
status: indexed
indexed_date: YYYY-MM-DD    # today
updated: YYYY-MM-DD         # today
updated_by: [current model]
agent_version: 03.26
created: YYYY-MM-DD         # add if missing
created_by: [current model] # add if missing
```

If no frontmatter block exists, prepend one. Do not create duplicate keys.

Keep a running list of files successfully stamped (`STAMPED`) and files that failed to stamp with the reason (`FAILED`).

### Step 3: Refresh the Index

```bash
bash "$SCRIPT" index
```

The index builds anywhere Python runs (ONNX path, see `/refresh-index`). Run `bash "$SCRIPT" index --budget 150` and repeat while it exits 3 (partial, progress saved); usually one call is enough because only changed chunks are embedded. If it cannot build (exit code 2), record `index: not rebuilt - Winnow will rebuild it when Obsidian is open` and continue.

If the indexer fails, log a warning and continue - move and extraction proceed without a fresh index. **Record the outcome either way**, it goes into state in Step 7.

### Step 4: Extract Insight Candidates

Spawn the `insight-extractor` agent that ships with this plugin (listed as `winnow:insight-extractor`) with all discovered file paths:

```
Task(
  subagent_type="winnow:insight-extractor",
  prompt="Vault: [$VAULT_BASE_PATH]. Extract insights from the following notes: [comma-separated full paths]. Follow your workflow and the candidate contract (insight-capture-format)."
)
```

Wait for completion. Record how many candidate files exist in `$WN_CANDIDATES/` before and after, so the report carries a real number rather than the subagent's own claim.

**In Cowork** the vault is on the owner's computer, reachable only through `mcp__remote-devices__device_bash` (mounted at `$HOME/mnt/<vault folder>`). Say so in the prompt: give the vault as that mount path and add "the vault is reachable only through mcp__remote-devices__device_bash; use it for every read, search and write".

**Fallback - when the agent reports it could not reach the vault** (`Read: 0`, "vault unreachable", or BEFORE == AFTER while it claims candidates): do the extraction in this session. Read `${CLAUDE_PLUGIN_ROOT}/skills/insight-capture-format/SKILL.md`, then for the discovered files follow it exactly - read each source, one batch `dedup`, write the candidates, count BEFORE/AFTER. Note in the run-log line that the fallback ran. Never skip extraction silently because the agent failed.

### Step 5: Move New Notes and Quickreads

Essays and $WN_INBOX notes stay in place - skip them here.

```bash
mkdir -p "$WN_ANALYSED"

mv "$WN_NEW_NOTES/[filename].md" \
   "$WN_ANALYSED/[filename].md"
```

If a filename conflict exists in the destination, append `_[YYYY-MM-DD]` before the extension.

Record `MOVED`.

### Step 6: Verify - the step that makes this skill honest

Re-run the Step 1 discovery commands, unchanged. Call the new result `REMAINING`.

Then check:

```
DISCOVERED_TOTAL  ==  len(STAMPED) + len(FAILED)
len(REMAINING)    ==  len(FAILED)
```

**If either check fails, the run did not succeed.** Do not write "Complete". Instead:

- name every file that is in `DISCOVERED_TOTAL` but not in `STAMPED` or `FAILED`
- name every file still in `REMAINING` that is not in `FAILED`
- state plainly that the run is incomplete and the counts do not reconcile
- write the mismatch into the "Red" section of the state file

A silently dropped file is the failure this skill exists to prevent. A loud mismatch is a working skill; a quiet "Complete" over wrong numbers is not.

### Step 7: Report and Write State

```
## Process New Notes - [Complete | INCOMPLETE - counts do not reconcile]

Discovered: N  ($WN_INBOX: a, New Notes: b, Quickreads: c, Essays: d, extra intake: e; "not present" for sources this vault lacks)
Stamped: N
Failed: N  [list with reasons]
Still unprocessed after run: N  [list]

### Moved to Analysed pieces
- filename-1.md  (N total)

### Stamped in place (Essays, $WN_INBOX)
- note-1.md  (N total)

### Insight candidates created
N notes added to $WN_CANDIDATES/  (before: X, after: Y)

### Index
rebuilt ✓  |  ⚠ rebuild failed - [error]

---
Next step: review the candidates in the Selection queue in Obsidian (or run /graduate-insights to go through them here)
```

Then append to `$WN_STATE`:

- one line at the top of **Run log**:
  `YYYY-MM-DD | process-new-notes | N found -> N processed -> N left | [ok | MISMATCH: ...]`
- update **Live metrics**: index rebuild timestamp (if it succeeded), candidate count, with today's date in the "Checked" column
- append anything that broke to **Red**

## Error Handling

| Error | Recovery |
|-------|----------|
| Folder missing | Skip that source, report it as skipped, do not count it as zero |
| No files found | Report and stop |
| Index rebuild fails | Log warning, continue, record in state |
| Extraction subagent fails | Log warning, still do the move, record in state |
| Move conflict | Append date suffix, reattempt |
| Counts do not reconcile | Report INCOMPLETE, name the files, write to Red. Never report Complete. |
