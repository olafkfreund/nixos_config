---
name: obsidian
description: Read, write, search and reorganise notes in the local Obsidian vaults. Use for anything touching ~/Documents/R3_vault, ~/Documents/Synechron or ~/Documents/My_Obsidian_Vault/Privat — finding notes, adding or editing content, renaming/moving notes without breaking links, and daily notes. Triggers on "my notes", "my vault", "Obsidian", "write this up in my notes", or a request to look something up in personal documentation.
---

# Obsidian vaults

Three vaults, ~2950 notes. They are plain Markdown directories, so **`Read`,
`Write`, `Edit`, `Grep` and `Glob` are the primary tools** — use them directly.
The CLI below exists for the two things file tools cannot do safely.

| Vault | Path | Notes | Registered in Obsidian? |
|---|---|---|---|
| R3 | `~/Documents/R3_vault` | 872 | **No** |
| Work | `~/Documents/Synechron` | 996 | Yes |
| Private | `~/Documents/My_Obsidian_Vault/Privat` | 1085 | Yes |

Ask which vault if the request is ambiguous. Content hints: Synechron holds
work/Jira/Confluence material and a `NixOS/` folder; Privat holds `AI/`,
`Linux/`, `Nixos/`, `CV/` and the only `Daily Notes/` folder; R3 holds
`Chats/`, `Context/`, `GitHub/`, `Interview/`.

## Conventions that actually hold here

These were measured across the real vaults, not assumed. Do not impose
conventions the vaults do not use.

- **Links are mostly standard Markdown, not wikilinks.** 2039 `[text](file.md)`
  vs 357 `[[wikilink]]`. Match whatever the file you are editing already uses;
  do not convert one style to the other.
- **Frontmatter is rare** — about 5% of notes have any, and most of what exists
  is plugin residue (`sticker`, `copilot-command-*`) or Kubernetes manifests
  (`apiVersion`/`kind`/`spec`). **Do not add YAML frontmatter to a note that
  has none.** Only touch frontmatter if the note already has it or the user asks.
- **No tag taxonomy.** `#word` occurrences are markdown headings and shell
  comments, not Obsidian tags. Do not invent tags.
- **Filenames** are mostly descriptive with no spaces and no date prefix.
  Follow the naming of sibling files in the target folder.
- `.obsidian/` is app state — never edit it.

## Normal work: just use the file tools

- Find a note: `Glob` `**/*keyword*.md`, or `Grep` for content
- Read: `Read`
- Create: `Write` (place it beside similar notes; match their heading style)
- Edit: `Edit`

Nothing about a vault makes these unsafe. Prefer them.

## Use `notesmd-cli` for these two things only

Installed as **`notesmd-cli`** (upstream renamed the binary; the repo is still
called obsidian-cli).

### 1. Renaming or moving a note

This is the one operation that is genuinely unsafe by hand: a rename must
rewrite every reference across ~2950 files, including heading anchors.

```bash
notesmd-cli move --vault Synechron "Old Note Name" "New Note Name"
```

Verified behaviour:

| Before | After |
|---|---|
| `[[Old]]` | `[[New]]` |
| `[Old](Old.md)` | `[Old](New.md)` — target rewritten, display text kept |
| `[[Old#Heading]]` | `[[New#Heading]]` |

Display text is deliberately preserved; if the user wants it renamed too, that
is a separate `Edit`.

**Never** do a rename with `mv` + `sed`. It misses heading anchors, block refs
and aliases, and corrupts links silently.

### 2. Daily notes

```bash
notesmd-cli daily --vault Privat
```

Only the Privat vault has a `Daily Notes/` folder. For the others, create a
dated note by hand in a sensible location.

## Constraint: `move` needs the vault registered with Obsidian

`move` reads `~/.config/obsidian/obsidian.json`, not just the CLI's own
registry. **R3_vault is not in it**, so `move` fails there with:

```text
Vault not found in Obsidian config file. Please ensure vault has been set up in Obsidian.
```

Options when that happens, in order of preference:

1. Use the vault's registered name exactly as it appears in `obsidian.json`
   (`notesmd-cli list-vaults` shows what the CLI knows).
2. Tell the user R3_vault must be opened once in the Obsidian app to register
   it — do not try to hand-edit `obsidian.json`.
3. Do the rename manually only if the user accepts the link-breakage risk, and
   say so explicitly first.

## Other subcommands

`create`, `delete`, `open`, `print`, `search`, `search-content`, `frontmatter`,
`list`, `list-vaults`, `add-vault`, `remove-vault`, `set-default-vault`.

Most duplicate what the file tools already do better in this context —
`search-content` is a plain substring search, so `Grep` is usually a better
choice. `open` launches the desktop app and should only be used when the user
asks to see a note in Obsidian.

## Safety

- Renames touch many files at once. State which vault and which note before
  running `move`.
- Never bulk-rewrite links with `sed` across a vault.
- Deleting notes: prefer confirming with the user; `delete` is not reversible
  from here and these vaults hold years of work.
