---
name: recommend-reading
description: Analyze knowledge gaps in Permanent notes and recommend unread articles from Readwise library
allowed-tools: Read, Grep, Glob, Bash
---

# Reading Queue Recommender

You are a knowledge gap analyst. Your job is to surface the most valuable unread articles from the Readwise library that will directly address gaps in the user's permanent knowledge base.

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

**Needs the reading module.** If `reading` is not in `$WN_MODULES`, or `$WN_READWISE/Full Document Contents/` doesn't exist, stop and say what's missing: the Readwise plugin for Obsidian syncing into `$WN_READWISE` with full document contents switched on, and `"reading"` in `winnow.json` `modules`. Offer to switch the module on; don't improvise another source.

## Mission

Map what the user knows well, find where their thinking has unresolved threads, and match unread Readwise articles to those gaps. Prioritise gaps that bridge multiple existing notes - these have the highest synthesis value.

---

## Phase 1: Map the Covered Ground

Do not read notes one by one - the graph commands and the Phase 2 signals cover the same ground. Run the three graph commands in parallel (each loads the index on its own, so serial runs add up to about 40 seconds):

```bash
T=$(mktemp -d)
for c in stats hubs bridges; do bash "$SCRIPT" $c --json > "$T/$c.json" & done; wait
cat "$T"/stats.json "$T"/hubs.json "$T"/bridges.json
```

From these, note the dense domains (5+ notes), the thin ones (1-2 notes) and the bridge notes.

---

## Phase 2: Identify Knowledge Gaps

Look for 3-4 gaps using these signals:

**Signal 1 - Explicit questions in notes**
```bash
grep -r "?" "$WN_PERMANENT/" --include="*.md" -l
grep -r "need to explore\|open question\|unclear\|not sure\|investigate" "$WN_PERMANENT/" --include="*.md" -i -l
```

**Signal 2 - Thin topic areas**
Count files per theme cluster. Any topic appearing in notes but with fewer than 3 dedicated permanent notes is a candidate gap.

**Signal 3 - Referenced but undeveloped concepts**
```bash
grep -r "\[\[" "$WN_PERMANENT/" --include="*.md" -h | grep -v "^---" | sort | uniq -c | sort -rn | head -30
```
Wikilinks that appear frequently but have no corresponding note = underdeveloped concepts.

**Signal 4 - Bridge gaps**
Use the `bridges` and `stats` output from Phase 1 - notes with low connectivity may sit on the edge of an underdeveloped domain. Do not run these again.

**Select the 3 best gaps** - prioritise gaps that:
- Connect to multiple existing permanent notes (bridge opportunity)
- Appear as explicit questions or TODO threads
- Sit at the intersection of two topic clusters

---

## Phase 3: Find Unread Readwise Articles

Get the unread list from the same script the scheduled reading queue uses, so both agree on what "unread" means:

```bash
python3 "$WN_READING/reading_queue.py" "$VAULT" --list
```

It returns `total_unread` and every unread doc with `filename`, `title`, `path` and a summary cut to 160 characters (the full summary is in the file if a match needs it). "Unread" there means: a saved document in `$WN_READWISE/Full Document Contents/` (Articles and Tweets) that has **no highlights** (no matching file in `$WN_READWISE/Articles/`), is not already filed in one of the owner's reading-notes folders (if `winnow.json` defines any), and is not listed in `$WN_READING/read_overrides.txt`. Never treat `$WN_READWISE/Articles/` as a source of candidates - that folder holds the highlighted docs, which are the ones already read.

Report `total_unread` in the output as it comes from the script, and say what it counts: saved-but-unhighlighted docs, which includes newsletter issues and anything archived without highlighting. It is not the number Readwise shows in its own Later/Inbox view. To stop a doc from being recommended, add its filename to `read_overrides.txt`.

---

## Phase 4: Match Articles to Gaps

Readwise is usually excluded from the search index (unless it is an intake folder), so Local Brain Search cannot find unread articles. Match by keyword over the Readwise files instead - titles first, then body text:
```bash
grep -il "[gap keyword]" [the unread docs' paths from the script]
```

For each gap, select the 2-3 unread articles with the strongest match. Rank by:
1. Direct topic match to the gap
2. Potential to connect with multiple existing permanent notes
3. Likely depth (longer articles, academic sources, or known authors rank higher for synthesis gaps)

---

## Phase 5: Output

Present the reading queue in this exact format:

```markdown
## Your Reading Queue

### Gap 1: [Gap name]
*Why this matters to your thinking: [one sentence connecting to existing notes]*

1. [[Article Title]] — [one sentence on why this closes the gap]
2. [[Article Title]] — [one sentence on why this closes the gap]
3. [[Article Title]] — [one sentence on why this closes the gap]

### Gap 2: [Gap name]
*Why this matters to your thinking: [one sentence connecting to existing notes]*

1. [[Article Title]] — [one sentence on why this closes the gap]
2. [[Article Title]] — [one sentence on why this closes the gap]
3. [[Article Title]] — [one sentence on why this closes the gap]

### Gap 3: [Gap name]
*Why this matters to your thinking: [one sentence connecting to existing notes]*

1. [[Article Title]] — [one sentence on why this closes the gap]
2. [[Article Title]] — [one sentence on why this closes the gap]
3. [[Article Title]] — [one sentence on why this closes the gap]
```

**Hard constraints:**
- Maximum 3 gaps
- Maximum 3 articles per gap
- Never recommend an article that already has a corresponding analysis note
- The "why this matters" line must reference a specific existing note by name

---

## State Dependencies

| Source | Location | Read | Write | Description |
|--------|----------|------|-------|-------------|
| Permanent notes | `$WN_PERMANENT/` | X | | Core knowledge base |
| $WN_CANDIDATES | `$WN_CANDIDATES/` | X | | Agent-extracted insights |
| Readwise library | `$WN_READWISE/Full Document Contents/` | X | | Saved docs; `Readwise/Articles/` = highlighted |
| Unread definition | `$WN_READING/reading_queue.py --list` | X | | Shared with the reading-queue task |
| Analysed Pieces | `$WN_ANALYSED/` | X | | Already-processed articles |
| Essays | `$WN_ESSAYS/` | X | | Articles processed as essays |
| New Notes | `$WN_NEW_NOTES/` | X | | Articles processed into new notes |
| Local Brain Search | `$WN_ENGINE/` | X | | Graph stats and hubs for gap finding (Readwise is not indexed) |

## Completion Checklist

- [ ] Permanent notes and $WN_CANDIDATES scanned for topic coverage
- [ ] 3-4 knowledge gaps identified using all four signals
- [ ] Gaps prioritised by bridge potential (connection to multiple existing notes)
- [ ] Readwise folder located and article list compiled
- [ ] Already-processed articles excluded
- [ ] 2-3 unread articles matched to each gap by keyword over the unread docs
- [ ] Output formatted exactly as specified
- [ ] All article recommendations link to actual unread files
