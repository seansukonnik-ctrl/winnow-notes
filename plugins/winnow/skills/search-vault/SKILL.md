---
name: search-vault
description: Quick search across the user's Obsidian vault combining semantic and keyword approaches. Use for rapid knowledge lookup, finding specific notes, or checking if something exists in the knowledge base.
argument-hint: <search query>
allowed-tools: Read, Bash, Grep, Glob
---

# Quick Vault Search

Fast search combining semantic FAISS and keyword grep.

## Commands

```bash
VAULT=$(bash "${CLAUDE_PLUGIN_ROOT}/scripts/resolve-vault.sh") || exit 1
WN_ENGINE="$VAULT/Winnow/search"; [ -d "$WN_ENGINE" ] || WN_ENGINE="$VAULT/resources/local-brain-search"
eval "$(python3 "$WN_ENGINE/winnow_env.py" "$VAULT")"   # folder names from winnow.json: $WN_PERMANENT, $WN_CANDIDATES, $WN_STATE ...
VAULT_BASE_PATH="$VAULT"
SCRIPT="$WN_SEARCH"

# Semantic search (top 5)
bash "$SCRIPT" search "$ARGUMENTS" --limit 5 --json

# Keyword fallback
grep -rl "$ARGUMENTS" "$WN_PERMANENT/" 2>/dev/null | head -5
```

## Instructions

1. Run semantic search, get top 5 results
2. Also grep permanent notes for keyword matches
3. Read full content of the single most relevant note
4. Return: top 5 results list + full content of #1

Keep output concise. This is a quick lookup, not deep analysis.
