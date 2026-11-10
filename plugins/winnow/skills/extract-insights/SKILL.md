---
name: extract-insights
description: Extract and capture the user's unique insights from a conversation, transcript, or text. Use when the user shares an original idea, personal theory, contrarian view, or experience-based wisdom that should be saved to the knowledge base. Verifies that every insight it claims to have saved is actually on disk.
argument-hint: <content to extract from, or "from conversation">
allowed-tools: Read, Write, Bash, Grep, Glob
---

# Extract Insights

Capture the user's own thinking from conversations or content and save it as candidate notes. Candidates, not permanent notes - `/graduate-insights` is what decides.

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


## The contract

What counts as the user's insight, the duplicate check, the candidate shape, the count check and the run-log line are defined once in `${CLAUDE_PLUGIN_ROOT}/skills/insight-capture-format/SKILL.md`. Read it and follow it. This skill only adds what is specific to capturing from a conversation or pasted text.

## Workflow

1. **Identify.** Read the content and list 2-5 distinct atomic insights before writing anything - step 4 checks against this list. A long dialogue walked highlight by highlight can carry 9-16; don't force the count down if the material has more.
2. **Duplicate check** - contract section 2. If a close permanent note already holds the claim, say so and offer to enrich it instead of writing a near-twin.
3. **Write** - contract section 3, with `source_type: conversation` (or `reading` when it came from a text the user reacted to). If the insight emerged in dialogue rather than from the user directly, say so in the body - it matters at graduation.
4. **Verify and record** - contract sections 4 and 5, skill name `extract-insights`.

## Report

```
## Extract Insights - Complete | INCOMPLETE
Identified: N   Saved: K (before X, after Y)   Enriched instead: E [which]
Dedup: semantic | manual | no permanent notes yet
- <title>  verified on disk
```
