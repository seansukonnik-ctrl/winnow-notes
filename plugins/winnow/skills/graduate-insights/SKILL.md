---
name: graduate-insights
description: Review candidate notes and promote worthy ones to permanent status using Zettelkasten principles. Verifies its own arithmetic, and never reports success on a mismatch.
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

# Graduate Insights

Review candidates from the holding area and promote worthy ones to `$WN_PERMANENT/`. This is the one stage where the decision is the user's, every time, by design - the skill surfaces and formats, it never decides.

## Holding areas

- **`$WN_CANDIDATES/`** - the live one. Personal insights extracted from conversations and reading.
- **`$WN_INBOX/`** (excluding the candidates folder itself and `Content Extractions/`) - raw captures.

Do not hardcode candidate counts into this file. They go stale within a week. Count them at run time.

## State Dependencies

| Source | Location | Read | Write |
|--------|----------|------|-------|
| System state | `$WN_STATE` | Yes | Yes |
| Q-values | `$WN_ENGINE/data/q_values.json` | Yes | No |
| Candidates | `$WN_CANDIDATES/` | Yes | Move / stub |
| Permanent Notes | `$WN_PERMANENT/` | No | Yes |
| Changelog | `$WN_CHANGELOGS/CHANGELOG - Graduation YYYY-MM-DD HHMM.md` | No | Yes |

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

### Step 0: Read state and count

Read `$WN_STATE`. If anything under "Red" affects this run - deletion blocked, search down - say so before starting.

Then count, and **write the number down**:

```bash
find "$WN_CANDIDATES/" -maxdepth 1 -name "*.md" -print0 | tr -dc '\0' | wc -c
```

Call this `CANDIDATES_BEFORE`. Step 6 checks against it. Also list the filenames - Step 6 needs names, not just a count.

### Step 0.5: Decisions already made in the Obsidian queue

The user reviews candidates in Obsidian too, in the **Selection queue** (Winnow Obsidian plugin). Each click there writes these lines into the candidate's frontmatter and nothing else:

| Field | Meaning |
|---|---|
| `review_decision` | `promote` / `hold` / `merge` / `delete` |
| `review_merge_into` | `"[[Permanent note]]"` - only with `merge` |
| `review_date` | the day they decided |
| `review_note` | optional instruction in their words ("merge the second paragraph only", "retitle it as a question") - follow it |
| `review_holds` | on how many separate days the note has been held |

Read these fields for every candidate from Step 0 and split them into three sets before doing anything else:

- **Decided** - `review_decision` is `promote`, `merge` or `delete`. The decision is made. Do not present these as candidates, do not ask again, do not offer a different option. Execute them: `promote` → Step 4, `merge` → Step 4b, `delete` → Step 5's delete branch without re-confirming (the click was the confirmation).
- **Held** - `review_decision: hold`. Leave in place. They resurface in their queue on their own; only bring one up if `review_holds` is 3 or more (Step 5's three-sessions rule).
- **Undecided** - no `review_decision`. Ask once whether they want to go through them here or in the Selection queue. If here, Steps 1-3 as usual; if there, stop after executing the decided set.

Deletes usually never reach you: the plugin sends them to the system trash when the user clicks "Move to trash". A file you listed in Step 0 cannot vanish mid-run, so this does not affect the arithmetic - just don't be surprised by a smaller pile than the last changelog suggests.

The plugin edits only the `review_*` lines and never rewrites the rest of the frontmatter. Keep it that way when you touch a candidate: don't reserialise its YAML (it turns `agent_version: 03.26` into `3.26`).

### Step 1: Prioritise

Rank candidates by, in order:

1. **Q-value > 0** - the note has actually been retrieved in a real search. `q_values.json` went dead between 2026-07-28 and 2026-09-15 because search was returning nothing; it is live again, but treat a thin file as "no signal yet" rather than "this note is worthless".
2. **Age > 14 days** - had time to settle.
3. **Has wiki-links to existing permanent notes.**

Take up to **5 per batch**, and prefer grouping by theme over strict ranking. Decisions within one theme come out more consistent than decisions across a scattered set.

### Step 2: Present each candidate

```
## Candidate [N/5]: [Note Title]

**Source:** [path]
**Created:** [date]  **Age:** [X days]  **Q-Value:** [value | not tracked]

### Content
[First 500 characters]

### Existing connections
[Wiki-links found, marking which point at permanent notes]

### Nearest permanent notes
[3 closest from search - this is the duplicate check, see below]
```

**Duplicate check is mandatory.** Run it once for the whole batch, before presenting the first card:

```bash
bash "$SCRIPT" dedup "$WN_CANDIDATES" --json
```

It compares every candidate with every permanent note (including ones promoted after the last index build) and with the rest of the batch. Verdicts, the one scale, and what to do with each are in the candidate contract (`insight-capture-format`, section 2) - use those. At graduation the extra step is presentation: a `duplicate` or `check` goes on the card as "Nearest note" with merge offered, and `same_batch` pairs are shown together. Say in the report which dedup method ran.

Two duplicates caught this way in Aug 2026 were both resolved by **merging**, not by deleting one side. A merged note carries `merged_from:` in frontmatter pointing at what it absorbed. Offer merge as a real option, not just promote/hold/delete.

### Step 3: Ask

**Decision for "[Note Title]":**
1. **Promote** - graduate to `$WN_PERMANENT/`
2. **Hold** - stays put, marked for enrichment
3. **Delete** - remove
4. **Merge into [existing note]** - fold into a note that already covers this

Never suggest a default. Never say which way you lean. This is the step the whole system exists to protect.

### Step 4: Promote

**Candidate shape.** Candidates follow the candidate contract (`insight-capture-format`): frontmatter, `# Title`, `> claim`, body, `## Connections`, `## Source`. Promotion keeps that shape. Older candidates may still be **legacy worksheets** (open with `## EXTRACTED INSIGHT`, no frontmatter): convert them to the same shape - `**Title**` to the H1, `**Claim**` to the `> ` line, `**Core Insight**` to the body unchanged, `**Context & Reasoning**` to `## Why This Matters`, `**Potential Connections**` to `## Connections` (only links that resolve), `**Source**` to `## Source`, `**Type**`/`**Keywords**` to frontmatter, and drop every other worksheet line and the `---` rules. The worksheet header must never reach `$WN_PERMANENT/`.

Frontmatter on a converted legacy worksheet (it has none of its own):

```yaml
---
created: [original date]
updated: [today]
created_by: [original model if present]
updated_by: [current model]
agent_version: 03.26
graduated_from: [original path]
graduated_date: [today]
---
```

For a candidate in the contract shape, keep its fields and add `graduated_from` / `graduated_date` / `updated` / `updated_by`. In both shapes, **drop** `status: candidate`, the `permanent-candidate` tag, every `review_*` field and `possible_duplicate` - they belong to the queue, not to a permanent note. A legacy worksheet decided in Obsidian carries a small frontmatter block holding only `review_*` lines; that block is not the note's frontmatter, build the real one as above.

**Title check.** Read `$WN_TITLE_STYLE` if it exists, otherwise `${CLAUDE_PLUGIN_ROOT}/references/title-style.md`. If the candidate's title breaks it (over 70 characters, a dash-clause, "not X but Y", kebab-case, jargon), rewrite it to the style at promotion without asking, and keep the old wording as the `> ` claim line under the H1 if the note doesn't open with one already. List every rewritten title in the report as `old → new`. A title the user wrote or asked for in `review_note` is kept as is.

Filename: `$WN_PERMANENT/[Title].md`. Offer a title/content refinement pass before writing, then move. If the decision came from the queue, skip the refinement offer unless `review_note` asks for it.

**Then handle the original.** Deletion is blocked on this setup (`rm` / `unlink` / `os.remove` return "Operation not permitted"; `mv` works). Attempt the delete anyway - it is cheap and may have been fixed - and if it fails, fall back **in this order**:

1. Try `device_request_delete_permission` on the vault folder. Untried as of 2026-09-16; if it works, everything below is unnecessary.
2. `mv` the original into `$WN_CANDIDATES/_to_delete/`.
3. Only if `mv` also fails, overwrite the original in place with a stub carrying `graduated: true` and a pointer to the new path.

**Record which branch ran, for every note.** In Aug 2026 the stub branch ran 32 times out of 32 and the skill reported a clean run each time - an emergency path that always fires is not an emergency path, it is the actual behaviour, and it belongs in the report and in `winnow-state.md`.

### Step 4b: Merge

Merge happens when the candidate and an existing permanent note are each half of one argument. Target: `review_merge_into` if the decision came from the queue, otherwise the note the user named.

1. Read both in full.
2. Draft the addition to the target: the candidate's core claim folded in as a paragraph (or two), keeping the user's own phrasing from the candidate - copy editor, not ghostwriter. Carry over any `## Connections` links the target doesn't already have. Follow `review_note` if there is one.
3. **Show every drafted merge in one message and write after one go-ahead.** The decision was theirs; the wording is yours, and it lands in a permanent note.
4. On the target: add `merged_from: [original path]` (append if the field exists), update `updated` / `updated_by`. Do not touch its other frontmatter lines.
5. Handle the candidate like a promoted original (Step 4's removal chain).

### Step 5: Hold and Delete

**Hold:** write the same fields the queue uses, so both paths share one record: `review_decision: hold`, `review_date: [today]`, and `review_holds` +1 (start at 1). Edit those lines only. The old `status: HOLD - Enrich` marker is still understood by the queue, but don't write new ones.

If a note has been held three sessions running, say so and ask directly whether it should be deleted instead. `immune-activation-as-a-cost-not-a-free-lunch` sat through three reviews unchanged - a note that never moves is a decision being avoided, not a note maturing.

**Delete:** confirm explicitly, then the same fallback chain as Step 4.

### Step 6: Verify

Recount the holding area with the exact command from Step 0. Call it `CANDIDATES_AFTER`.

Check:

```
promoted + deleted + merged  ==  CANDIDATES_BEFORE - CANDIDATES_AFTER   (if real deletion worked)
```

or, when the stub/move fallback ran:

```
CANDIDATES_AFTER  ==  CANDIDATES_BEFORE - moved_to_to_delete
```
with every promoted-but-not-removed original accounted for as either a stub or a file in `_to_delete/`.

Then verify the other end: every note listed as promoted **exists** at its new path in `$WN_PERMANENT/`. Check the files, do not trust the running tally.

**If anything does not reconcile:** do not write "Complete". Name the specific notes, say the run is incomplete, and append the mismatch to "Red" in `winnow-state.md`.

### Step 7: Report and write state

```
## Graduation - [Complete | INCOMPLETE - counts do not reconcile]

Candidates before: N    after: N
Promoted: N   Held: N   Deleted: N   Merged: N
Decided in the Selection queue: N (promote N / merge N / delete N)   Decided here: N
Originals removed: N deleted / N moved to _to_delete / N stubbed in place

### Promoted
- [[Note]] ← [original path]   [verified present in $WN_PERMANENT ✓]

### Held
- [[Note]] - [reason given]  [Nth session held]

### Duplicate check
via dedup (N duplicate, N check, N new) | via search | manual ([reason])
```

Then:

- append one line to **Run log** in `$WN_STATE`:
  `YYYY-MM-DD | graduate-insights | N candidates -> N decided -> N left | [ok | MISMATCH: ...]`
- update **Live metrics**: candidate count, permanent-note count, with today's date
- append anything that broke to **Red**, including the stub-fallback count if it fired
- write a dated changelog at `$WN_CHANGELOGS/CHANGELOG - Graduation YYYY-MM-DD HHMM.md` (dated file, not a running `CHANGELOG.md` - that is the convention the rest of the vault uses)

---

## Graduation criteria

**Promote if:** atomic (one idea), evergreen, connected, original, actionable.

**Hold if:** unripe, compound (needs splitting), missing the context that would let it stand alone.

**Delete if:** exact duplicate, extraction error, superseded.

**Merge if:** two notes are each half of one argument. Prefer this over deleting one side.

One category worth not second-guessing: self-knowledge and identity material sourced from introspective conversation rather than external reading is **established, welcome content in this vault** - there is a graduated cluster of it already. It is still fair to flag when a whole batch comes from one emotionally fresh conversation and may not have settled, but that is a timing question, not a category question.

## Notes

- Human judgment is the point, not an obstacle to automate around.
- Batch of 5 keeps a session completable.
- Weekly cadence prevents the backlog that makes review feel like a chore.
