---
name: recall
description: Retrieve relevant knowledge from the user's Obsidian vault using 3-layer semantic search. Use when asked to recall, remember, look up, find notes about, or search the knowledge base for any topic.
argument-hint: <search query or topic>
allowed-tools: Read, Bash, Grep, Glob
---

# Semantic Knowledge Retrieval

Retrieve knowledge from the user's vault using multi-layer semantic FAISS search.

## Setup

```bash
VAULT=$(bash "${CLAUDE_PLUGIN_ROOT}/scripts/resolve-vault.sh") || exit 1
WN_ENGINE="$VAULT/Winnow/search"; [ -d "$WN_ENGINE" ] || WN_ENGINE="$VAULT/resources/local-brain-search"
eval "$(python3 "$WN_ENGINE/winnow_env.py" "$VAULT")"   # folder names from winnow.json: $WN_PERMANENT, $WN_CANDIDATES, $WN_STATE ...
VAULT_BASE_PATH="$VAULT"
SCRIPT="$WN_SEARCH"
```

## Search Commands

```bash
# Layer 1 — spreading activation (best for synthesis)
bash "$SCRIPT" search "$ARGUMENTS" --mode spreading --limit 5 --json

# Layer 2 — connections from top result
bash "$SCRIPT" connections "Top Result Note Name" --json

# Layer 3 — hub notes for wider context
bash "$SCRIPT" hubs --json
```

## Instructions

**Layer 1 — Direct matches:**
Run spreading search. Read full content of top 2 results with `Read` tool from vault path.

**Layer 2 — First-degree associations:**
Get connections for the top result. Read full content of top 2 connected notes.

**Layer 3 — Extended network:**
Check hub notes for deeper context and unexpected connections.

## Output Format

```markdown
# Knowledge Recall: [Query]

## Layer 1: Direct Matches
[Notes with scores and key excerpts]

## Layer 2: First-Degree Associations
[Connected notes with relationship explanations]

## Layer 3: Extended Network
[Hub notes and bridge connections]

## Key Insights
[Synthesized themes and connections]

## Relevant Content
[Most pertinent excerpts]
```

If search returns no results, try broader terms. Highlight unexpected connections.
