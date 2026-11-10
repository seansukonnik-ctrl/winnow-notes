---
name: setup-vault
description: First-time setup of a new user's Obsidian vault - a short calibration interview, then folders, config, the Obsidian plugin, the search index and a first pass over their notes. Use when someone says set up my vault, get started, onboard me, or when another skill reports that no vault was found.
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

# Set up a vault

Turns an ordinary Obsidian vault into one this system can work in, and calibrates it to the person who owns it. The interview is the product's first impression and its calibration at once: keep it short, specific and about them.

The system has two halves that talk only through files in the vault: the Obsidian plugin **Winnow** (the human side: Selection queue, Vault state, maps) and this Claude plugin (the agent side: extraction, graduation, search, terrains). This skill wires both into the vault.

## Ground rules

- **Never overwrite or move the user's existing notes** - with one opt-in exception, promote-directly (question 5), where the user approves the exact list of notes to move. Otherwise setup only adds folders and files. The one existing file it may change is `.obsidian/community-plugins.json` (to switch Winnow on), and an existing `CLAUDE.md` gets a section appended, never replaced.
- **Show the full list of what will be written, get one go-ahead, then write.** Nothing is written during the interview.
- Folder, file, field and command names stay in English whatever language the conversation is in. Note bodies are in whatever language the user writes.
- Never use the em-dash character in anything written to the vault; use a spaced hyphen.
- One question at a time in the interview. AskUserQuestion for choices, plain conversation for open questions. Stop asking once you have enough; ten minutes is the target.

## Step 0: Find the vault and check the kit is in it

The user's vault must be a folder Claude can reach: in Cowork, a connected folder (it shows up under `$HOME/mnt/<folder>` in the device shell); in Claude Code, the current directory or `$VAULT_BASE_PATH`.

```bash
for d in "${VAULT_BASE_PATH:-}" "$HOME"/mnt/*/ "$PWD"; do
  d="${d%/}"; [ -n "$d" ] && [ -d "$d/.obsidian" ] && (cd "$d" && pwd -P)
done | sort -u
```

- No folder with `.obsidian/` in it: ask the user to connect their vault folder (Cowork: "Add folder" in the desktop app) and stop.
- Several: ask which one is the vault.

Then check the kit files are in the vault. The user unzips the kit into the vault root before running this skill (see the kit's README):

```bash
VAULT="<the vault>"
eval "$(python3 "$VAULT/Winnow/search/winnow_env.py" "$VAULT")"   # folder names; before winnow.json exists these are the defaults below
ls "$VAULT/.obsidian/plugins/winnow/main.js" "$WN_SEARCH" \
   "$WN_ENGINE/onnx_model/model.onnx" "$VAULT/Winnow/kit/CLAUDE.template.md" 2>&1
```

The default layout of a new vault, which this skill creates (the user sees four folders, everything technical sits in `Winnow/`):

```
Inbox/               where they write; Claude reads new notes from here
Inbox/Candidates/    what Claude proposes; decided in the Selection queue
Permanent Notes/     what they kept
Terrains/            their living stances on broad areas (only once there is one)
Winnow/              state file, owner profile, templates, changelogs, the search engine (Winnow/search) and the kit
```

Every skill reads these names from `winnow.json` (`folders`), so a vault set up differently keeps its own names. Never hard-code a folder name; use the `$WN_*` variables.

Anything missing: say which file, tell them to unzip the kit into the vault root (the folder that contains `.obsidian`), and stop. If `winnow.json` already exists, the vault was set up before: say so, show its contents, and ask whether they want to redo the interview (it updates the profile and config; notes are untouched) or stop.

## Step 1: Look before asking

Read the vault's shape so the interview asks about their vault, not a generic one:

```bash
cd "$VAULT"
find . -name "*.md" -not -path "./.obsidian/*" -not -path "./Winnow/*" -not -path "./resources/*" | wc -l
for d in */; do case "$d" in Winnow/|resources/) continue;; esac; printf "%6s  %s\n" "$(find "$d" -name '*.md' | wc -l)" "$d"; done | sort -rn | head -20
ls -a; [ -f CLAUDE.md ] && head -30 CLAUDE.md
find . -name "*.md" -not -path "./.obsidian/*" -not -path "./Winnow/*" -not -path "./resources/*" -newermt "$(date -d '-30 days' +%F 2>/dev/null || date -v-30d +%F)" | wc -l
```

Open 3-4 notes from the biggest folders (one recent, one old) to see how they write: their own prose, highlights, clippings, daily notes, meeting notes. Note whether there is a Readwise, Kindle or web-clipper folder (imported material, not their thinking).

Tell the user in two or three sentences what you see ("about 600 notes, most in Reading/ and Journal/, Readwise highlights in Readwise/, 40 notes written this month") before the first question.

## Step 2: The interview

Aim: learn enough to (a) tell their thinking from what they imported, (b) know which folders feed the system, (c) seed the first terrain. Ask in this order, skipping anything Step 1 already answered.

1. **Name and language.** What to call them; which language(s) they write notes in.
2. **What they do and read.** Their work in a sentence; what they read most (sources, formats); how material gets into the vault (Readwise, copy-paste, typing notes while reading, dictation).
3. **What they want back.** AskUserQuestion, multi-select: remember and retrieve what I've read and thought / see connections I missed / know what I actually think about a topic / turn notes into drafts / keep a map of my views. This tells you what to demonstrate in Step 5.
4. **Where their own thinking lives.** Show the folder list from Step 1 and ask which folders hold *their* notes (reactions, arguments, ideas) as opposed to imported highlights or reference material. Those become intake folders. Imported-only folders (Readwise, clippings) are not intake by default: the extractor only keeps what the user said about a source, and a raw highlight has nothing of theirs in it yet. **But if they write their own reactions inside an imported folder** (a Readwise `Note:` under a highlight, comments in a clipping), that folder *is* intake - list it, and record the marker in the owner profile. Listing a folder as intake also makes it searchable (the search engine's default exclusions, such as `Readwise`, never apply to an intake folder).
   Then ask the reverse: which folders should search *ignore* - raw clippings, templates, anything that is never theirs and would crowd their own notes out of results. These go to `index_exclude`.
5. **The backlog.** How much of the existing material should go through extraction now: a sample of the most recent notes (default: 15), a named folder or topic, or none. Everything older than today is otherwise left alone; new and edited notes flow in from now on.
   **Offer promote-directly when it fits.** If Step 1 showed notes that are already atomic - one claim, in their own words, a title that is a point (a `Thinking/` folder of short argued notes is the typical case) - extracting them would only produce candidates that restate each note. Offer instead to promote them straight to `$WN_PERMANENT/`. Build the list yourself (at most 30 at a time, most recent first) and show it: file name, the one-line claim you read in it, and a house-style title suggestion where theirs breaks the style. They can take all, some, or none. Notes that make two points, or mix their thinking with quoted text, stay out of this list and go through extraction instead.
6. **Reading.** If Step 1 or question 2 showed Readwise (a `Readwise/` folder, or they said they highlight in Readwise/Kindle), confirm the folder it syncs into. That switches on the **reading** module: their reactions under highlights can be intake (question 4), and `/recommend-reading` matches what they saved but haven't read against open questions in their notes. No Readwise: leave the module off and say it can be switched on later.
7. **A coarse take.** "Pick a broad area you have a strong, maybe crude, opinion on - crypto, remote work, AI agents, anything. What's your one-line take?" Then two or three follow-ups to pull out the finer sub-takes, especially the ones that contradict the one-liner. This becomes their first Terrain in Step 4. If they'd rather not, skip it (the terrains module stays on; the folder is created with the first terrain).

Keep their own words. The owner profile quotes them rather than paraphrasing.

## Step 3: Show the plan, get one go-ahead

List every file and folder to be created, and the one existing file to be changed:

```
Folders:   Inbox/  Inbox/Candidates/  Permanent Notes/  Terrains/ (only with a first terrain)
           Winnow/Templates/  Winnow/Changelogs/
Files:     winnow.json
           CLAUDE.md                          (new | section appended to your existing one)
           $WN_OWNER_PROFILE
           $WN_STATE
           $WN_TEMPLATES/Terrain Template.md
           $WN_TERRAINS/<Area>.md              (if they gave a coarse take)
Changed:   .obsidian/community-plugins.json   (adds "winnow")
Moved:     <N notes> -> $WN_PERMANENT/         (only if they chose promote-directly; list every file)
Then:      build the search index, extract from <N notes / folder>
```

Wait for the go-ahead.

## Step 4: Write

Use today's date and the model you are running as for all metadata (`created`, `updated`, `created_by`, `updated_by`, `agent_version: 03.26`). Templates are in `$VAULT/Winnow/kit/`.

1. **Folders:** `mkdir -p` the list above. Existing folders are fine.
2. **`winnow.json`** in the vault root:
   ```json
   {
     "kit_version": "<from Winnow/kit/VERSION>",
     "owner": "<name>",
     "setup_date": "<today>",
     "languages": ["<as they said>"],
     "intake": ["<folders from question 4, vault-relative, forward slashes>"],
     "intake_since": "<today>",
     "index_exclude": ["<folder names search should skip, from question 4; [] if none>"],
     "voice_profile": null,
     "modules": ["terrains", "reading"],
     "folders": {
       "inbox": "Inbox", "candidates": "Inbox/Candidates", "permanent": "Permanent Notes",
       "terrains": "Terrains", "system": "Winnow", "engine": "Winnow/search",
       "readwise": "<their Readwise folder, only with the reading module>"
     }
   }
   ```
   `modules`: `terrains` always; `reading` only if question 6 found Readwise - otherwise `["terrains"]`. Other modules (maps, writing, research) exist but stay off for now; don't offer them. `folders` is written out in full so the layout is visible in one place; anything left out falls back to the defaults above. Re-read the variables after writing it: `eval "$(python3 "$VAULT/Winnow/search/winnow_env.py" "$VAULT")"`.
   `intake_since` is what keeps the pre-setup backlog out of routine runs. `index_exclude` and `intake` are read by the search engine at every index build: intake folders are always indexed, `index_exclude` folders never are. `/process-new-notes` always reads `$WN_INBOX/` as well; it does not need to be listed.
3. **`CLAUDE.md`:** fill `Winnow/kit/CLAUDE.template.md` (replace `{{OWNER}}`, `{{SETUP_DATE}}` and `{{INTAKE_FOLDERS}}`). If the vault already has a `CLAUDE.md`, append the filled template under a `## Knowledge system` heading instead, leaving their text above it untouched.
4. **`$WN_OWNER_PROFILE`:** from the interview, in this shape. Quote them; don't embellish; nothing they didn't say.
   ```markdown
   ---
   <mandatory metadata>
   type: owner-profile
   ---
   # Owner profile

   ## Who
   <name, work, in their words>

   ## What they read, and how it gets in
   <sources, formats, which folders are imported material>

   ## Where their own thinking lives
   <intake folders, and what a note of theirs looks like - "short reactions under a highlight", "long dictated essays", ...>

   ## What they want back
   <from question 3>

   ## How to tell their thinking from the source's
   <one or two concrete markers from the notes you read in Step 1, e.g. "their comments follow '->' under a highlight", "journal entries are theirs, Reading/ is mostly quotes">
   ```
5. **State file:** copy `Winnow/kit/state.template.md` to `$WN_STATE` (keep that exact path: the Vault state panel reads it) and fill the date.
6. **Terrain template:** copy `Winnow/kit/Terrain Template.md` to `$WN_TEMPLATES/Terrain Template.md`.
7. **First terrain** (if they gave a coarse take): `mkdir -p "$WN_TERRAINS"`, then write `$WN_TERRAINS/<Area>.md` following the `/terrain` skill's CREATE workflow, from what they said in the interview. With an empty vault there are no notes to link yet: mark every sub-take `(no note yet - capture candidate)`, texture `forming`. Show it to them before writing, as part of the Step 3 go-ahead or right after.
8. **Switch Winnow on:** add `"winnow"` to the JSON array in `.obsidian/community-plugins.json` (create the file with `["winnow"]` if it doesn't exist). Edit with a short python read-modify-write, keeping every entry already there.

## Step 5: Build the index and run a first pass

0. **Promote-directly** (only for the notes they approved): `mv -n` each into `$WN_PERMANENT/` keeping its file name, so every wiki-link to it keeps resolving. Then edit only its frontmatter (create a block if there is none, never re-serialise an existing one): add `status: permanent`, `promoted_date: <today>`, `promoted_from: <old folder>`, `updated`, `updated_by`, `agent_version: 03.26`, and `created` from the file's modification date if missing. If they accepted a new title, add it under `aliases:` rather than renaming the file. Don't touch the body. Count the moved files in `$WN_PERMANENT/` against the approved list; on a mismatch, stop and say which didn't move. The owner profile (Step 4) says their thinking lives in that folder *and* that its atomic notes were promoted on setup day, so later runs don't look for them there. Set "Permanent notes" in the state file's Live metrics to the real count. Do this before the index build, so the duplicate check in step 3 has real permanent notes to compare against.

1. **Index:**
   ```bash
   bash "$WN_SEARCH" index --budget 150
   ```
   Exit code 3 means partial with progress saved: run it again, in a new call, until it exits 0. A vault of a few hundred notes takes one or two calls; the first build of a large one can take several. If it cannot build at all (exit code 2), say so and continue: search falls back to keywords until Winnow or a later run builds it.
2. **First extraction:** take the backlog choice from question 5 (by default the 15 most recently modified notes in the intake folders) and run the `insight-extractor` agent on them, as `/process-new-notes` Step 4 does, with the vault path and the note paths. Then stamp those notes (`status: indexed`, `indexed_date`) exactly as `/process-new-notes` Step 2 does, so the routine run doesn't pick them up twice.
3. **Duplicate check** on the new candidates: `bash "$WN_SEARCH" dedup "$WN_CANDIDATES" --json`. On a fresh vault with no permanent notes yet there is nothing to compare against except the other candidates: the output carries a `warning` saying so, every verdict is `new`, and only `same_batch` means anything. Don't report that as "no duplicates found".
4. **Count** the candidates actually on disk. That number goes in the wrap-up, not the agent's own claim.

## Step 6: Wrap up

Tell the user, briefly:

- What was set up (one line) and how many candidates are waiting.
- **In Obsidian:** restart Obsidian or reload it (Ctrl/Cmd+P -> "Reload app without saving"). If community plugins are in Restricted mode, they need to turn that off once (Settings -> Community plugins) - Winnow is already installed and listed as enabled, Obsidian just has to be allowed to run it. Then open the **Selection queue** (inbox icon in the left ribbon): each candidate gets promote / hold / merge / delete. That queue is the heart of the system: the machine proposes, they decide.
- **After deciding:** run `/graduate-insights` here; it executes the promote and merge decisions. Deletes are done by the queue itself.
- **Routine:** put new thinking in `$WN_INBOX/` or the intake folders, and run `/process-new-notes` when there's a batch. **Vault state** (the pulse icon) shows what's waiting and what Claude changed.
- **Reading** (only if the module is on): `/recommend-reading` suggests what to read next from what they saved in Readwise.
- Optional, for automatic index rebuilds while Obsidian is open: `$WN_ENGINE/setup-python` (see the kit README). Without it, Claude rebuilds the index during `/process-new-notes`.

Then record the run:

- `$WN_STATE` -> Run log: `YYYY-MM-DD | setup-vault | <N> notes in vault, <P> promoted directly, <M> extracted -> <K> candidates | ok`
- `$WN_CHANGELOGS/CHANGELOG - Setup YYYY-MM-DD HHMM.md`: what was created, the intake folders, the backlog choice, the candidate count, anything that failed.

## If something fails

| Problem | What to do |
|---|---|
| No `.obsidian` in any reachable folder | Ask them to connect the vault folder; stop |
| Kit files missing | Name the missing file; ask them to unzip the kit into the vault root; stop |
| Index build fails (exit 2) | Continue without it; say search is keyword-only until it's built; note it in Red in the state file |
| Extractor produces nothing | Say so plainly; offer to try a different set of notes or a folder they point at |
| `community-plugins.json` can't be parsed | Don't rewrite it; tell them to enable Winnow by hand in Settings -> Community plugins |
