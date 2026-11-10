---
name: start
description: First run on a fresh Winnow starter vault - a short calibration interview, a topic conversation saved as the first note, index build, and first extraction. The vault is already set up; /start fills it in for this person. Use when someone types /start after opening their starter vault.
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

# Start

Turns the starter vault into this specific person's vault. The folders, plugin and search engine are already there; this skill adds the owner, the first conversation, and the first batch of candidates.

Aim: short, warm, ten minutes tops. They should end up with candidates waiting in the Selection queue before they've written a single note of their own.

## Step 0: Check the vault is ready

```bash
VAULT=$(bash "${CLAUDE_PLUGIN_ROOT}/scripts/resolve-vault.sh") || exit 1
WN_ENGINE="$VAULT/Winnow/search"
eval "$(python3 "$WN_ENGINE/winnow_env.py" "$VAULT")"
VAULT_BASE_PATH="$VAULT"
SCRIPT="$WN_SEARCH"
```

If the resolver fails: ask them to open a Cowork task and add their vault folder ("Add folder" button), then run `/start` again.

Check the kit is in place:

```bash
ls "$WN_ENGINE/brain_search.sh" "$WN_ENGINE/winnow_env.py" \
   "$WN_ENGINE/onnx_model/model.onnx" 2>&1
```

Missing files: tell them the starter vault zip is incomplete and stop.

If `winnow.json` already has an `owner` field that is not `"friend"` and not empty, the vault was already calibrated. Say so, show the name and setup_date, ask if they want to redo the calibration or stop.

## Step 1: Short questions (3-4, one at a time)

Do not explain the system before asking. Start with the first question.

1. **Name.** What to call them. (AskUserQuestion or plain conversation - keep it casual.)
2. **What they do and read.** Their work or main interest in a sentence; what they tend to read or consume most.
3. **What they want back.** AskUserQuestion, multi-select:
   - Remember and retrieve what I've read and thought
   - See connections I'd otherwise miss
   - Know what I actually think about a topic
4. **Readwise.** "Do you use Readwise? It's a service that collects your highlights and saves them. If yes, the Readwise plugin in Obsidian (already installed in your vault) pulls them in automatically - you just need to sign in once." AskUserQuestion: Yes, I'll sign in now / No / I'll set it up later.

If they choose "Yes, I'll sign in now": tell them to open Obsidian -> Community plugins -> Readwise Official -> Options -> and sign in with their Readwise account. Wait for them to confirm before continuing.

## Step 2: Topic interview (10 minutes, conversational)

Pick 2-3 topics from what they said in Step 1 (their work, their reads, or their stated wants). Ask one open question per topic, follow up once or twice to pull out their actual take - not summaries of what they read but what they themselves think.

Good follow-ups: "What's your honest take on that?" / "Where do you disagree with the consensus?" / "What keeps coming back to you about it?"

Aim for their own words, their own angles. If they give you a surface answer, probe once more then move on.

## Step 3: Save the transcript

Write their answers - not the questions, not the full Q&A, just their own words shaped into first-person paragraphs - to:

```
$WN_INBOX/Start - interview YYYY-MM-DD.md
```

Frontmatter:

```yaml
---
created: YYYY-MM-DD
created_by: <current model>
updated: YYYY-MM-DD
updated_by: <current model>
agent_version: 03.26
type: interview
---
```

One paragraph per topic. Keep their phrasing; don't embellish. This note will be processed by the extractor; it only works if the claims are genuinely theirs.

## Step 4: Calibrate winnow.json and write the owner profile

Update `winnow.json` with these fields (merge, do not replace):

```json
{
  "owner": "<their name>",
  "setup_date": "<today>",
  "languages": ["<as they said, default: English>"],
  "intake": ["Inbox"],
  "intake_since": "<today>",
  "index_exclude": [],
  "modules": ["reading"],
  "folders": {
    "inbox": "Inbox",
    "candidates": "Inbox/Candidates",
    "permanent": "Permanent Notes",
    "system": "Winnow",
    "engine": "Winnow/search",
    "reading": "Winnow/reading",
    "readwise": "Readwise"
  }
}
```

If they said no Readwise: set `"modules": []` and omit `"readwise"` from folders.

Re-read the env after writing: `eval "$(python3 "$WN_ENGINE/winnow_env.py" "$VAULT")"`.

Then write `$WN_SYSTEM/owner-profile.md` from the interview, following the same shape as setup-vault Step 4 owner profile (who, what they read, where their thinking lives, what they want back). Quote them. Nothing they did not say.

Then fill in `$VAULT/Winnow/kit/CLAUDE.template.md` (replace `{{OWNER}}`, `{{SETUP_DATE}}`, `{{INTAKE_FOLDERS}}` with `Inbox`) and write it to `$VAULT/CLAUDE.md`. If a `CLAUDE.md` already exists and was written by the kit (starts with `# Knowledge system`), overwrite it. If the user has their own CLAUDE.md with other content, append under a `## Knowledge system` heading.

## Step 5: Build the index and extract

```bash
bash "$SCRIPT" index --budget 150
```

Repeat while exit code is 3 (partial). If exit code 2, note it and continue.

Then run extraction on the interview note (follow the same call as process-new-notes Step 4):

```
Task(
  subagent_type="winnow:insight-extractor",
  prompt="Vault: [$VAULT_BASE_PATH]. Extract insights from: [$WN_INBOX/Start - interview YYYY-MM-DD.md]. Follow the insight-capture-format. The owner is [name]. These are their own words from an interview, so every claim is theirs."
)
```

Stamp the interview note with `status: indexed`, `indexed_date: today`.

Count candidates in `$WN_CANDIDATES/` before and after.

## Step 6: Wrap up

Tell them briefly:

- How many candidates are waiting (use the before/after count, not the agent's claim).
- **In Obsidian:** open the **Selection queue** (inbox icon, left ribbon). Each card is a candidate insight extracted from your interview. Promote the ones that feel right, skip or hold the rest. That is the whole decision - nothing happens without you choosing.
- **After deciding:** come back to this task and run `/graduate-insights` to move your choices into Permanent Notes.
- **To add more:** write in Inbox/ anytime - a reaction to something you read, a half-formed thought, whatever. When you have a few, run `/process-new-notes`.
- **To ask your vault:** once you have permanent notes, try `/get-perspective-on <topic>` or `/recall <keyword>`.

Write to `$WN_STATE`:
- Run log line: `YYYY-MM-DD | start | interview -> N candidates | ok`
- Update Live metrics: candidate count, today's date.
