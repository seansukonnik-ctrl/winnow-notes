---
name: synthesize-insights
description: Combine multiple notes or insights into a coherent narrative, framework, or model. Use when asked to synthesize, combine, or find patterns across multiple ideas or notes.
argument-hint: <topic, theme, or list of note names>
allowed-tools: Read, Bash, Grep, Glob, Write
---

# Synthesize Insights

Combine scattered insights into coherent frameworks, narratives, or models.

## Setup

```bash
VAULT=$(bash "${CLAUDE_PLUGIN_ROOT}/scripts/resolve-vault.sh") || exit 1
WN_ENGINE="$VAULT/Winnow/search"; [ -d "$WN_ENGINE" ] || WN_ENGINE="$VAULT/resources/local-brain-search"
eval "$(python3 "$WN_ENGINE/winnow_env.py" "$VAULT")"   # folder names from winnow.json: $WN_PERMANENT, $WN_CANDIDATES, $WN_STATE ...
VAULT_BASE_PATH="$VAULT"
SCRIPT="$WN_SEARCH"
```

## Workflow

**Step 1 — Gather relevant notes:**
```bash
bash "$SCRIPT" search "$ARGUMENTS" --mode spreading --limit 12 --json
bash "$SCRIPT" connections "most relevant note" --json
```
Read full content of 5-10 most relevant notes.

**Step 2 — Identify patterns:**
Look for:
- Recurring mechanisms across different domains
- Tensions and contradictions between notes
- Missing pieces that would complete a framework
- Cross-domain analogies

**Step 3 — Build synthesis:**
- Name the framework or model (coin a term)
- Show how individual insights combine into something bigger
- Identify what the synthesis predicts or enables
- Note what questions it raises

**Step 4 — Output options:**
- Article outline
- Framework description with named concept
- MOC draft (for create-moc follow-up)
- Standalone synthesis note saved to `$WN_CANDIDATES/` (with the CLAUDE.md frontmatter), so `/graduate-insights` reviews it

## Output Format

```markdown
# Synthesis: [Named Framework/Model]

## The Pattern
[What emerges when these insights are combined]

## Source Notes
- [[Note 1]] — contributes X
- [[Note 2]] — contributes Y

## The Framework
[Description of the synthesized model]

## What This Predicts
[Implications and applications]

## Gaps and Questions
[What's missing, what to explore next]

## Content Applications
[Article angles, video topics, etc.]
```
