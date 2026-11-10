---
name: refresh-index
description: Rebuild the semantic search index after adding or modifying notes in the vault. Use when asked to refresh the index, re-index the vault, or after adding many new notes.
allowed-tools: Bash
---

# Refresh the search index

Rebuild the semantic search index so new and modified notes are searchable.

## When to Run

- After adding 5+ new permanent notes
- After a large extraction or research session
- When search results feel stale or miss obvious notes
- After moving or renaming notes

## Commands

```bash
VAULT=$(bash "${CLAUDE_PLUGIN_ROOT}/scripts/resolve-vault.sh") || exit 1
WN_ENGINE="$VAULT/Winnow/search"; [ -d "$WN_ENGINE" ] || WN_ENGINE="$VAULT/resources/local-brain-search"
eval "$(python3 "$WN_ENGINE/winnow_env.py" "$VAULT")"   # folder names from winnow.json: $WN_PERMANENT, $WN_CANDIDATES, $WN_STATE ...
VAULT_BASE_PATH="$VAULT"
bash "$WN_SEARCH" index
```

Builds wherever Python runs: with sentence-transformers if installed (the Windows venv), otherwise with the ONNX export in `onnx_model/` (onnxruntime + tokenizers + numpy + networkx, installed on first use, ~40 MB). Same vectors either way. Never pip-install torch or sentence-transformers in a sandbox; those installs time out and are not needed.

Vectors are cached per chunk (`data/embed_cache.pkl`), so a rebuild only embeds what changed and usually takes seconds. The first build of a large vault can take several minutes, longer than one shell call may run, and background jobs do not survive the end of a call. So build in slices:

```bash
bash "$WN_SEARCH" index --budget 150
```

Exit code 3 means "partial, progress saved": run the same command again, in a new call, until it exits 0 and prints `INDEXING COMPLETE`. Each slice embeds for about 150 seconds.

If Obsidian is open with Winnow, it also rebuilds the index by itself (Vault state -> Search index -> Rebuild now, and automatically when notes change). Don't start a second build while its status bar says "Indexing…".

## What It Does

- Scans all notes in the vault (folders in `memory_config.py` `excluded_folders` are skipped)
- Generates embeddings with all-MiniLM-L6-v2
- Writes the vectors (`embeddings.npy`, plus `brain.faiss` when faiss is installed) and the note graph
- Updates `$WN_ENGINE/data/`: `embeddings.npy`, `brain_metadata.pkl`, `brain_graph.pkl`

## Notes

- The index lives in the vault, in `$WN_ENGINE/data/`
- Safe to run at any time - non-destructive
- `q_values.json` (usage learning) is preserved
