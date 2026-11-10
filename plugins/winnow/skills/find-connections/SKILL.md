---
name: find-connections
description: Discover hidden connections between notes in the user's knowledge base. Use when asked to find connections, map relationships, discover links between concepts, or explore how ideas relate to each other.
argument-hint: <note name or topic>
allowed-tools: Read, Bash, Grep, Glob
---

# Connection Discovery

Map the conceptual network around a note or topic, revealing direct connections, bridge notes, and emergent patterns.

## Commands

```bash
VAULT=$(bash "${CLAUDE_PLUGIN_ROOT}/scripts/resolve-vault.sh") || exit 1
WN_ENGINE="$VAULT/Winnow/search"; [ -d "$WN_ENGINE" ] || WN_ENGINE="$VAULT/resources/local-brain-search"
eval "$(python3 "$WN_ENGINE/winnow_env.py" "$VAULT")"   # folder names from winnow.json: $WN_PERMANENT, $WN_CANDIDATES, $WN_STATE ...
VAULT_BASE_PATH="$VAULT"
SCRIPT="$WN_SEARCH"

# Direct connections for a note
bash "$SCRIPT" connections "$ARGUMENTS" --json

# Semantic neighbors
bash "$SCRIPT" search "$ARGUMENTS" --limit 10 --json

# Hub notes (most connected)
bash "$SCRIPT" hubs --json

# Bridge notes (cross-domain connectors)
bash "$SCRIPT" bridges --json
```

## Instructions

1. Get direct connections for the specified note/topic
2. Run semantic search to find thematically similar notes
3. Check hub and bridge notes for cross-domain links
4. Read content of 3-5 most interesting connected notes
5. Synthesize the connection map

## Output Format

```markdown
# Connection Map: [Note/Topic]

## Direct Connections
[Notes with explicit links and similarity scores]

## Thematic Neighbors
[Semantically similar notes — what they share]

## Bridge Notes
[Cross-domain connectors — why they matter]

## Emergent Patterns
[Non-obvious relationships and what they suggest]

## Synthesis Opportunities
[Ideas that could be combined into articles or frameworks]
```

Prioritize unexpected connections over obvious ones. Explain WHY each connection is interesting.
