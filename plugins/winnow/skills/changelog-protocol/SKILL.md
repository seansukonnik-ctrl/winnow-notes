---
name: changelog-protocol
description: The one rule for session records - when a dated changelog is worth writing, how it is named and what goes in it. Every skill that writes a changelog follows this; not invoked on its own.
user-invocable: false
---

# Changelog protocol

There are two records and each has one job:

- **Run log** in `$WN_STATE` - one line per run, every run, newest first. This is the index of everything that happened. The Vault state panel in Obsidian shows it.
- **Dated changelog** in `$WN_CHANGELOGS/` - only for a run worth reading later: 10+ candidates written, 3+ notes changed or moved, a discovery session, a structural change. Small runs get the Run log line and nothing else.

There is no master `CHANGELOG.md`. It duplicated the Run log, and every changelog that linked dozens of notes turned it into the top hub of the search graph. Old vaults may still have one; leave it alone, don't add to it.

## Name

`CHANGELOG - <Session type> YYYY-MM-DD HHMM.md` - time included, so two runs on one day never overwrite each other. Get it from `date '+%Y-%m-%d %H%M'`.

## Content

Short. A reader should get it in a minute.

```markdown
---
created: YYYY-MM-DD
created_by: <model>
agent_version: 03.26
type: changelog
---

# <Session type> - YYYY-MM-DD HH:MM

<Two or three sentences: what ran, on what, why.>

## Result
<Counts that were checked on disk, and what was written or changed, with [[links]].>

## Worth a look
<Decisions the owner should make, surprises, anything that failed. Omit if empty.>
```

No statistics nobody asked for, no "cognitive fingerprint", no template sections left as "none". If a section would be empty, drop it.
