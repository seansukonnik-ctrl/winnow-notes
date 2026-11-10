# winnow-release

The public release repo for Winnow Notes. It is a Claude Code / Cowork plugin marketplace (`.claude-plugin/marketplace.json`) and, later, the home of release assets (starter vault zip) and release tests.

## Sources live in the vault, not here

The vault is the sibling folder `../Synced_PKM` (absolute path in the untracked `CLAUDE.local.md`; override with `WINNOW_VAULT`). Never run git inside it. Paths below are relative to the vault. Single sources of truth:

- `resources/winnow-plugin/src` - Claude plugin (`build.py`, `editions/modules.json`, `VERSION`)
- `resources/winnow-obsidian` - Obsidian plugin
- `resources/winnow-kit-src` - kit / starter vault builder
- `resources/local-brain-search` - search engine

This repo only receives build outputs. Never hand-edit `plugins/winnow/`: change the source in the vault, bump `VERSION`, then run `./publish.sh` (or `publish.ps1`). Cowork only sees an update when the version in `plugin.json` changes, so do not set `version` in `marketplace.json`.

Launch brief: `resources/winnow-friends-launch/BRIEF.md` in the vault.

## House rules

- No em-dashes anywhere; use a spaced hyphen ( - ).
- File names, headings, fields, commands and settings in English.
- Never ship anything personal: no notes, people, names from the vault, local paths, keys, emails, or friends/admin code paths. The publish scripts refuse to copy a build that contains obvious personal strings; keep that guard and extend it rather than bypassing it.
- Commit and push only from this folder.
