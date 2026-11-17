---
status: approved
issue: 2982
author: olafkfreund
---

# Intent: run a key from the herdr-app key help (hintr parity)

## Problem

In the Herdr TUI, hintr (`wraithyy/herdr-hintr`, <https://github.com/wraithyy/herdr-hintr>) opens a popup that lists
the bindings in `config.toml`. Pressing a listed key runs that binding
(`home/development/herdr.nix`, lines 245-253). herdr-app's `app.help` is the "keys dialog" and only lists keys
(`herdr-app commands`: "Toggle the keys dialog"). The approved spec for Issue #2978 recorded this as a partial gap
(`spec/2026-11-16-2978-herdr-app-parity.md`, Part 4 table and the Gaps list) and `docs/applications/herdr.md`
(Known gaps, line 395) points here. The question is whether a which-key style mod is worth building.

## Proposed outcome

Recommendation: do not build a full which-key mod now. Close Issue #2982 as won't-fix, but only after the owner
answers question 1 below. Edit the Known gaps row in `docs/applications/herdr.md` to say what the palette covers and
what it does not. Reasons:

- The two tools solve different problems. hintr exists because the TUI uses a prefix key: you press `prefix`,
  then a letter you must remember. herdr-app has no prefix. Our keys are direct chords (`ctrl-h/j/k/l`,
  `ctrl-shift-g`, `ctrl-shift-u`, `ctrl-shift-i`, see the spec Keys table), so a key you can read in the dialog
  you can already press. I have not verified how the help dialog routes chords; that stays open.
- `app.palette` (`ctrl-shift-p`) lists and runs commands. Source check of
  `~/.config/herdr-app/frame/palette/main.js`: submit and click call `go()`, which closes the overlay and runs the
  command (lines 136, 150). It shows each command with its bound key via `keys()` (line 208).
- Coverage gap in the palette. It is built from `commands()`, which the `.d.ts` says excludes mods' own
  `<mod>.<command>`s (`herdr.d.ts` line 280). So `splits.worktree-open` (`ctrl-shift-u`) and `mod.open:inbox` are
  not palette entries. The lazygit and zoe bindings (`herdr-app.nix` lines 46-48) carry `argv` and `place`, but the
  palette only offers a generic `terminal.open` with empty arguments (`main.js` line 45). Searching "lazygit"
  cannot reproduce them. The palette therefore does not cover our custom bindings.
- A mod can read the live key table. `herdr.d.ts` line 385 exports `keys(): {section, keys, action}[]`, and the
  shipped palette already uses it. The earlier "wait for upstream" premise was wrong and is dropped. What remains
  is whether a mod can dispatch a returned `action` with its arguments correctly.
- hintr's execution is narrower than first stated. Upstream README
  (<https://github.com/wraithyy/herdr-hintr#what-it-shows>) limits direct execution to `shell` and `plugin_action`
  bindings; built-ins are display only (reported by Codex, not re-read by me). The `herdr.nix` comment (lines
  245-246) repeats the overstatement. The parity target is "run shell and plugin bindings", not every binding.
- herdr-neovim's which-key work is a different shape. `houz42/herdr-whichkey`
  (<https://github.com/houz42/herdr-whichkey>) is a hierarchical group popup with its own mnemonic key tree that it
  dispatches through the Herdr CLI. `Qu4tro/herdr-whichkey` (<https://github.com/Qu4tro/herdr-whichkey#readme>)
  offers single-key actions, groups and repeated resize. Both add a new key scheme, not a viewer of the existing
  one, and target the TUI. I could not find a repo named "lazyvim-whichkey".

If the owner wants it, the cheapest version is one small mod: a list from `keys()` where selecting an entry runs
`herdr-app do <command>`, plus entries for the mod bindings the palette misses.

## Affected users and systems

- The owner on p620, razer and p510 (hosts that run herdr-app via `home/development/herdr-app.nix`).
- Files touched if won't-fix: only `docs/applications/herdr.md` (Known gaps row) and the issue itself.
- Files touched if built: a new folder under `home/development/herdr-app/mods/`, one `keys.json` entry in
  `home/development/herdr-app.nix` and a docs line. No service, host or secret is involved.

## Constraints

- The installed `herdr-app` reports 0.1.15; this checkout declares 0.1.16 (`pkgs/herdr-app/default.nix` line 27).
  The spec's "re-checked against 0.1.16" is planned work, not evidence. The mod API is young, so a mod may break
  on a bump.
- Mods are trusted JavaScript with command and network access. Anything we add is code we maintain.
- Reuse over new code: the app's own palette and `app.help` are the first choice (ponytail: the smallest change).
- AGENTS.md rules apply: explicit imports, nav changes in both `mkdocs.yml` and `mkdocs-full.yml` (none expected),
  and no change reaches p510 without the owner's OK.

## Open questions

1. Is the palette enough? Decide between two aims: **execute existing bindings** (palette plus a few missing
   entries is close) or **introduce a mnemonic menu** (single-key, grouped, as in the whichkey projects; the palette
   does not give this). Recommendation: if search-and-Enter is acceptable, close as won't-fix and document the gap
   for mod bindings; otherwise reopen as a small `keys()`-based mod.
2. Does the help dialog (`app.help`) accept chords while open? Not verified. Recommendation: check once by hand
   (the guide says not to drive the real display automatically).
3. Can a mod run a `keys()` action that carries `argv`/`place` (lazygit, zoe)? Recommendation: check
   `herdr.d.ts` `do()` and the `open` helper before any spec.
4. Close or park? Recommendation: park until question 1 is answered, then close or spec accordingly.

## Decision

Approved by the owner on 2026-11-17, with the recommendation given for each open question above.
