---
name: terrain
description: Create or update a Terrain - a living worldview cloud sitting above permanent notes. Use when the user voices a coarse stance whose subtleties are richer than the take, when discussion shifts an existing stance, or when asked to map/update a terrain on a broad topic (Crypto, AI agents, Transparency, etc.).
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
user-invocable: true
arg-description: "<terrain name, or 'update <terrain>'>"
---

# Terrain

## Setup

```bash
VAULT=$(bash "${CLAUDE_PLUGIN_ROOT}/scripts/resolve-vault.sh") || exit 1
WN_ENGINE="$VAULT/Winnow/search"; [ -d "$WN_ENGINE" ] || WN_ENGINE="$VAULT/resources/local-brain-search"
eval "$(python3 "$WN_ENGINE/winnow_env.py" "$VAULT")"   # folder names from winnow.json: $WN_PERMANENT, $WN_CANDIDATES, $WN_STATE ...
VAULT_BASE_PATH="$VAULT"
```

Create and maintain Terrains: a note type that sits ABOVE permanent notes and captures the user's living stance on a broad area as a cloud, not a fixed position.

## What a Terrain is

People think in clouds, with an inversion: the broader the topic, the cruder and more one-polar the top-level take; the deeper they dig, the more subtleties appear that get blurred into one flat verdict. A Terrain holds both ends at once.

Anatomy (structure under "the field" is FLEXIBLE - two poles, one grouped list, or loose tags, whatever fits the cloud):
- **Coarse take** - the crude shadow, true from far away, deliberately blunt. One line. Does not pretend to be the whole truth.
- **The field** - the finer sub-takes, often contradicting the coarse take and each other. Tension is held, not resolved. Each links to the permanent note that carries it `[[note]]`; ones with feeling but no note yet are marked `(no note yet - capture candidate)`.
- **What fell out of the cloud** - the subtler thesis the coarse take was hiding. May be "still tangled" if it has not resolved.
- **What would reshape this** - falsification conditions and live tensions.
- **Terrain log** - dated, newest first, tracking how the cloud's SHAPE moved.

## Hard rules

- **Never quantify.** Confidence is `texture` - a word (forming / settling / settled / internally-tense / contested), never a number. A numeric confidence on a qualitative cloud is bad faith.
- **Never silently auto-edit.** Always show the proposed change and get the user's go-ahead before writing: the offer first, then their confirmation.
- **Do not flatten the user** into their coarse take. The point of the format is the subtlety underneath.
- Follow vault conventions: `.md`, mandatory frontmatter metadata (see CLAUDE.md), hyphens not em-dashes, `created_by`/`updated_by` = the model currently running (model-agnostic).
- Use the template at `$WN_TEMPLATES/Terrain Template.md`. If it is missing, use the anatomy above with this frontmatter: `type: terrain`, `texture: forming`, `last_reshaped: <today>`, `domains: []` plus the mandatory metadata.

## Usage

```
/terrain <terrain name>          # create a new terrain
/terrain update <terrain name>   # update an existing terrain
```

## Workflow - CREATE

1. **Check for an existing Terrain** in `$WN_TERRAINS/`. If one exists, switch to UPDATE.
2. **Surface the user's coarse take** in their own words - blunt, one line. Do not soften it.
3. **Excavate the field.** Pull the finer sub-takes from what the user has said in this conversation. Then search the vault for permanent notes that already carry these sub-takes and link them:
   ```bash
   bash "$WN_SEARCH" search "<sub-take>" --limit 5 --json
   ```
   Link real notes only. Mark sub-takes with no backing note as `(no note yet - capture candidate)` - these are the terrain telling the user where to dig next.
4. **Look for the thesis that fell out.** Often the coarse take is the crude shadow of a sharper claim already half-present in the field or in an existing permanent note. Name it if it is there; write "still tangled" if it is not.
5. **Write the file** to `$WN_TERRAINS/<Terrain name>.md` from the template. Title = the territory (broad area), not the verdict - the verdict lives inside and is allowed to move.
6. **Seed the terrain log** with a first dated entry describing the initial shape and texture.
7. Tell the user what capture candidates surfaced (sub-takes with feeling but no note) - these are candidate permanent notes.

## Workflow - UPDATE

1. **Read the existing Terrain.**
2. **Identify what moved**: a new sub-take, a reshaped or newly-resolved thesis, a texture shift, a new capture candidate, or a genuine contradiction with what is already there.
3. **Propose the diff to the user and wait for go-ahead.** Never write silently.
4. On confirmation: edit the relevant section, prepend a dated entry to the **terrain log** describing the SHAPE change (not a number), update `texture`, `updated`, `updated_by`, `last_reshaped` in frontmatter.
5. If the update introduced a contradiction the cloud cannot yet hold, leave it visible in the field rather than resolving it artificially - unresolved tension is honest information.

## Proactive behaviour

This skill is the hands; the trigger lives in CLAUDE.md (always-on layer). In any conversation touching a domain with a Terrain, consult it as the user's worldview lens, and when discussion would move a Terrain, OFFER to run this skill rather than waiting to be asked.

## After changes

Suggest `/refresh-index` so new or changed Terrains enter semantic search (Winnow also does this by itself while Obsidian is open).
