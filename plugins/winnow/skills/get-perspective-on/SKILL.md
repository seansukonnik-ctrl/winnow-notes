---
name: get-perspective-on
description: Extract the user's unique perspective on any topic from their knowledge base. Use when asked "what do I think about X", "what's my take on Y", "get my perspective on Z", or when writing content that should reflect the user's views.
argument-hint: <topic or question>
allowed-tools: Read, Bash, Grep, Glob
---

# Get the User's Perspective

Extract the user's unique perspective on a topic from their permanent notes and extracted insights.

## Setup

```bash
VAULT=$(bash "${CLAUDE_PLUGIN_ROOT}/scripts/resolve-vault.sh") || exit 1
WN_ENGINE="$VAULT/Winnow/search"; [ -d "$WN_ENGINE" ] || WN_ENGINE="$VAULT/resources/local-brain-search"
eval "$(python3 "$WN_ENGINE/winnow_env.py" "$VAULT")"   # folder names from winnow.json: $WN_PERMANENT, $WN_CANDIDATES, $WN_STATE ...
VAULT_BASE_PATH="$VAULT"
SCRIPT="$WN_SEARCH"
```

## Workflow

**Step 1 — Search knowledge base:**
```bash
bash "$SCRIPT" search "$ARGUMENTS" --mode spreading --limit 8 --json
```

**Step 2 — Keep their voice:** write plainly and keep the user's own phrasing from the notes wherever you quote or paraphrase them; don't invent a style.

**Step 3 — Read top 3-5 relevant permanent notes in full**

**Step 4 — Synthesize perspective:**
- 1-3 paragraphs, in the user's voice
- Prioritize contrarian or non-obvious angles
- Cite specific permanent notes with [[wikilinks]]
- Include "why this matters"

## Quality Criteria

✅ Good: cites 3-5 specific notes, highlights contrarian angles, concrete examples, authentic voice
❌ Weak: generic knowledge, no note citations, surface-level, no unique angle

## Output Format

```
Your perspective: [Topic]

[1-3 paragraphs synthesizing unique insights in the user's voice]

Key insights:
- [Insight from [[Note A]]]
- [Insight connecting [[Note B]] and [[Note C]]]

Why this matters:
[Brief significance or application]

Cited notes:
- [[Note 1]]
- [[Note 2]]
```

Keep brief. This is perspective extraction, not a full article.
