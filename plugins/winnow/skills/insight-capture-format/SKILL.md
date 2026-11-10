---
name: insight-capture-format
description: The one contract every skill that writes candidate notes follows - the candidate note shape, the duplicate check, the count check and the run-log line. Read by extract-insights, insight-extractor, extract-document-insights and deep-research; not invoked on its own.
user-invocable: false
---

# Candidate contract

Every candidate note in the vault is written one way, by every skill. Four skills write candidates (`extract-insights`, the `insight-extractor` agent, `extract-document-insights`, `deep-research`); this file is the only place the shape, the duplicate check and the verification are defined. If a skill's own text disagrees with this file, this file wins.

Candidates go to `$WN_CANDIDATES/` and wait for the owner's decision in the Selection queue or `/graduate-insights`. They are never written to `$WN_PERMANENT/` directly.

## 1. What counts

An insight is the owner's only if they agreed, disagreed, or saw something the source did not say. A good point by an author, a summary of the argument, or a smooth reconstruction of something they half-said is not theirs. If `$WN_OWNER_PROFILE` exists, read it first: it says how to tell their thinking from what they imported.

Document extraction (`source_type: document`) is the one exception: there the claim is the source's, and the note says so through `epistemic_status`.

Types, one list for every skill: Personal Theory, Contrarian View, Synthesis, Experience Wisdom, Mental Model, Pattern, Value Discovery, Research Finding (documents only).

## 2. Duplicate check - once per batch

Empty a scratch folder outside the vault (for example `$HOME/dedup-drafts`), write every draft into it as its own file - title as the file name, the one-sentence claim as the body - then one call, and empty the folder again afterwards:

```bash
bash "$WN_SEARCH" dedup "$HOME/dedup-drafts" --json
```

One scale, the dedup scale, nowhere else:

| Verdict | Score | Do |
|---|---|---|
| `duplicate` | 0.75+ | Read the match. Same claim: skip it, and if the new source adds evidence, say so in the report as an enrichment suggestion. Never edit a permanent note while extracting. |
| `check` | 0.55-0.75 | Read the match. Paraphrased duplicates hide here. Write only if the angle is really different. |
| `new` | below 0.55 | Write. |

- `same_batch` flags two drafts that say the same thing - keep one.
- A match against the note you are extracting from is the source, not a duplicate. Ignore it.
- If the output has a `warning` (no permanent notes yet), every verdict is `new` by default - say so in the report, don't call it "no duplicates found".
- If dedup exits 2 (no index), grep `$WN_PERMANENT/` titles for the key words instead and say the check was manual.
- Decide by reading, never by the number alone.

When you write a candidate despite a close match, name the match in `possible_duplicate` (below). The queue turns it into a one-click merge. Leave the field out when nothing came close.

## 3. The shape

Title first, by the house style - `$WN_TITLE_STYLE` if it exists, otherwise `${CLAUDE_PLUGIN_ROOT}/references/title-style.md`. That file is the only definition of titles and file names; don't work from memory of it.

```markdown
---
created: YYYY-MM-DD
updated: YYYY-MM-DD
created_by: <the model actually running>
updated_by: <same>
agent_version: 03.26
status: candidate
type: <one type from section 1>
source_type: <conversation | note | reading | document>   # conversation = said in a chat with Claude; note = written in their own notes; reading = their reaction to something they read (Readwise notes, comments on a clipping, a daily note about an article); document = the source's claim, not theirs
tags: [topic, tags]
possible_duplicate: "[[Closest note]]"      # only when a close match exists
epistemic_status: <confirmed | theoretical | hypothesis | speculative>   # documents only
source_url: <url>                              # documents only, when there is one
---

# <Title>

> <The precise claim, one sentence>

<The insight in 2-4 sentences, in the owner's own phrasing - or, for a document, the finding>

## Connections
- [[Related note]] - how it relates   (permanent notes only; the source goes under Source, other candidates aren't linked)

## Source
<file path, conversation date, or title and author>
```

This is the shape the Selection queue reads (title from `# `, claim from `> `, source from `## Source`, merge offer from `possible_duplicate`) and the shape `/graduate-insights` promotes. Nothing else. If the insight emerged in dialogue rather than from the owner directly, say so in the body.

## 4. Count and verify

Count the files in `$WN_CANDIDATES/` before writing (`BEFORE`) and after (`AFTER`). `AFTER - BEFORE` must equal the number you report, and every file you name must exist and be non-empty. On a mismatch, say the run is incomplete, name what didn't land, and put the mismatch under Red in `$WN_STATE`.

## 5. Record

One line at the top of the Run log in `$WN_STATE`:

`YYYY-MM-DD | <skill> | N read -> K candidates (D skipped as duplicates) | ok`

Zero candidates is a valid result (`ok`) when the sources had nothing of the owner's in them - say which notes and why in the report. It is `MISMATCH` only when the count check in section 4 fails.

Update "candidates waiting" in Live metrics if the file has that row. A dated changelog only when the run wrote 10 or more candidates, following `changelog-protocol`.
