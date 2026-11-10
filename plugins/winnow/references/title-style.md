# Title style

How Winnow names notes. Applies to every candidate in `$WN_CANDIDATES/` and every note promoted to `$WN_PERMANENT/`. If the vault has its own `$WN_SYSTEM/title-style.md`, that copy wins: it is the user's edited version of this one.

## The one rule

**Say it the way you'd say it across the table.** If a friend asked "so what's the note about?", the title is what comes out of your mouth. Not the abstract, not the thesis statement. The spoken version.

The precise claim is not lost. It moves into the first line of the note, where it has room to be exact (see "Where the precise claim goes").

## The rules

1. **Short.** 3 to 9 words, about 60 characters. Hard ceiling 70. A list of titles should be skimmable in one pass.
2. **One thought.** No second clause after a dash. No "not X but Y", no "X, not Y", no "X rather than Y". Pick the half that carries the surprise; the other half goes in the body.
3. **Plain words.** Words you'd use out loud. Drop: structurally, fundamentally, mechanism, paradigm, leverage (as a verb), disproportionately, category error, the X pattern, is the same as, universal failure mode. Keep proper nouns and the one term of art the note is actually about.
4. **Still a point, not a topic.** "Robot security" is a folder name. "Robot makers skip security until forced" is a note. Someone reading only the title should be able to guess what the note argues.
5. **Warmth is allowed.** A bit of wit, a concrete image, a verb with some life in it ("bully", "gets gamed", "first easy win"). Not jokes for their own sake, and never at the cost of rule 4.
6. **Sentence case, no full stop.** Only the first word and proper nouns capitalised. No kebab-case, no Title Case.
7. **Filename-safe.** No `: / \ * " < > | ?` in the filename (Windows refuses them). A question title keeps its `?` in the `# ` heading and drops it from the filename.
8. **Distinct.** Before saving, check the title against existing note names. Two notes that sound alike in a list will get confused in links.

## Allowed shapes

Mix them. Most titles are plain statements; roughly one in five can be one of the others.

| Shape | Example |
|---|---|
| Plain statement | Every imposed metric gets gamed |
| "X is just Y" | Coding is just AI's first easy win |
| Question you have an answer to | Why would Latin America pick US money? |
| Short contrast, no dash | AI reads the chart, the doctor keeps the blame |
| Advice | Check the cost curve before crediting genius |
| Image | Robots get better in small steps |

## Before and after

| Before | After |
|---|---|
| Trump's foreign policy contradicts the maritime-power playbook the US is structurally built for | Trump plays America like a land power |
| Latin America has no structural reason to prefer the US over China as an investment partner | Why would Latin America pick US money? |
| The 'take my money or I'll fund your rival harder' leverage only works for the single biggest fund | Only the biggest fund can bully founders |
| Coding is a big market but a small problem - it's just the only one AI has solved for everyone | Coding is just AI's first easy win |
| Audience breadth is a search mechanism for rare depth matches not the goal | A big audience is how you find your few readers |
| Robotics progress is gradient ascent not a giant leap threshold | Robots get better in small steps |
| Goodhart's Law is the universal failure mode of imposed measurement systems | Every imposed metric gets gamed |

## Where the precise claim goes

The first line under the `# ` heading is the claim in full, as a quote line:

```markdown
# Robots get better in small steps

> Robotics progress is gradient ascent not a giant leap threshold.

There's no single fundamental innovation that will suddenly make robots "work"...
```

That line is what search, the duplicate check and a careful reader lean on. The title is for humans scanning a list; the claim line is for precision. Write both, every time.

In a worksheet candidate (the `## EXTRACTED INSIGHT` shape) the claim is the `**Claim**:` line and the title is the `**Title**:` line.

## Renaming an existing note

Only when the user asks. Then:

- rename the file and the `# ` heading;
- put the old title in `aliases:` in frontmatter and in `renamed_from:`, so old wording still finds it in Obsidian's quick switcher and search;
- add the old title as the `> ` claim line if the note doesn't already open with one;
- repoint every `[[Old title]]`, `[[Old title|...]]` and `[[Old title#...]]` in the vault to the new name;
- rebuild the search index afterwards (notes are indexed by path).
