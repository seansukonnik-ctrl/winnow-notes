---
name: create-moc
description: Build a Map of Content (MOC) from permanent notes on a topic. Use when asked to create a MOC, map a topic, or organize notes on a subject into a navigable overview.
argument-hint: <topic>
allowed-tools: Read, Write, Bash, Grep, Glob
---

# Create Map of Content (MOC)

Build a navigable overview of a topic from existing permanent notes.

## Setup

```bash
VAULT=$(bash "${CLAUDE_PLUGIN_ROOT}/scripts/resolve-vault.sh") || exit 1
WN_ENGINE="$VAULT/Winnow/search"; [ -d "$WN_ENGINE" ] || WN_ENGINE="$VAULT/resources/local-brain-search"
eval "$(python3 "$WN_ENGINE/winnow_env.py" "$VAULT")"   # folder names from winnow.json: $WN_PERMANENT, $WN_CANDIDATES, $WN_STATE ...
VAULT_BASE_PATH="$VAULT"
SCRIPT="$WN_SEARCH"
```

## Workflow

**Step 1 — Gather notes:**
```bash
bash "$SCRIPT" search "$ARGUMENTS" --limit 20 --json
bash "$SCRIPT" connections "most relevant note" --json
```
Collect 10-20 relevant permanent notes and candidates from `$WN_CANDIDATES/`.

**Step 2 — Cluster into groups:**
Identify 3-5 thematic clusters. Give each a descriptive name.

**Step 3 — Write MOC:**

```markdown
---
created: YYYY-MM-DD
updated: YYYY-MM-DD
created_by: [the model actually running]
updated_by: [same]
agent_version: 03.26
tags: [moc, topic]
---

# [Topic] - Map of Content

## Overview
[2-3 sentence framing of what this topic covers and why it matters]

## [Cluster 1 Name]
- [[Note A]] - [one-line description]
- [[Note B]] - [one-line description]

## [Cluster 2 Name]
- [[Note C]]
- [[Note D]]

## Cross-Domain Bridges
[Notes that connect this topic to other domains]

## Adjacent Topics
[Related MOCs or topics worth exploring next]

## Synthesis Opportunities
[Article or framework ideas suggested by this cluster]
```

**Step 4 — Save:**
`$WN_MOCS/[topic-name].md`
