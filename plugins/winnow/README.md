# Winnow for Claude (friends edition 0.9.7-core)

The Claude half of Winnow. The other half is the Winnow Obsidian plugin; they talk only through files in your vault.

Start with `/setup-vault`.

| Skill | What it does |
|---|---|
| `setup-vault` | First-time setup: short interview, folders, config, index, first pass over your notes |
| `process-new-notes` | Routine intake: new notes in Inbox and your intake folders become candidates |
| `extract-insights` | Capture your own thinking from a conversation or a text you paste |
| `graduate-insights` | Carry out the decisions you made in the Selection queue (or decide here) |
| `recall` / `search-vault` | Find what you've written about something |
| `find-connections` | Map how a note or topic connects to the rest |
| `get-perspective-on` | What do I actually think about X, from my own notes |
| `synthesize-insights` | Combine several notes into one argument or framework |
| `create-moc` | A map of content for a topic |
| `refresh-index` | Rebuild the local search index |
| `recommend-reading` | What to read next from your Readwise saves (reading module) |
| `self-diagnostic` | What's actually working in the system right now |

## Your vault after setup

```
Inbox/               where you write
Inbox/Candidates/    what Claude proposes - decide them in the Selection queue
Permanent Notes/     what you kept
Winnow/              everything technical: settings, state, search engine
```

Folder names and switched-on modules live in `winnow.json` in the vault root.

