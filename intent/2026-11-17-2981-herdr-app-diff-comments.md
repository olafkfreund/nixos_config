---
status: draft
issue: 2981
author: olafkfreund
---

# Intent: herdr-app sends diff line comments to the agent (reviewr parity)

## Problem

In the Herdr TUI, the `persiyanov.reviewr` plugin (`home/development/herdr.nix:285-296`,
`docs/applications/herdr.md:123-140`) lets you select diff lines, comment on them
and send every comment into the agent's input. A review becomes "annotate the
diff, press send" instead of retyping findings into a prompt.

herdr-app has no such round trip. The shipped `changes` mod
(`~/.config/herdr-app/mods/changes/main.js`, 212 lines, `"place": "none"`) lists
files, shows one file's diff and commits. It has no line selection, no comment
input and no send step. The gap is recorded in `docs/applications/herdr.md:394`
and was accepted in the approved spec for Issue #2978
(`spec/2026-11-16-2978-herdr-app-parity.md:438`).

## Proposed outcome

Community mods already cover most of this, so the first question is whether to adopt one
as is, adapt one, or write our own. That choice is left open (question 1). Verdict on the
issue itself: **do**, with a small step.

In a herdr-app window on p620 and razer, the owner opens a diff panel, selects
one line or a range, types a comment, and repeats. One "send" action pastes all
comments into the agent's input in the same tab, with the file path and the
quoted lines for each. With several agents in the tab, a picker asks which.
This matches reviewr's behaviour.

The sent text lands in the agent's input but is **not** submitted, as in reviewr.
reviewr's `send_text` pastes "unsubmitted, in one socket request" through the herdr
`pane.send_text` method (`src/herdr.rs:683-694` at bb71050). `hc send` always presses
Enter (`hc send --help`: "paste text and press enter"), so the mod must paste
without Enter. How it does that is a spec question, not an intent one.

Candidates found online, all MIT, all herdr-app mods using `hc`:

- vytasgavelis/herdr-reviewer: a clone of the shipped `changes` mod with line
  comments, a send dialog, four scopes. Tested on herdr-app 0.1.13, 17 stars.
  <https://github.com/vytasgavelis/herdr-reviewer>. Known differences from the outcome
  above (`mods/reviewer/dialog.js:51-98` at 01e6d10, README):
  - It submits with Enter (`hc send`), not paste-only.
  - For a working or blocked agent it asks to confirm, then runs `hc send --force`. That
    can type review text into a permission dialog, which the constraints forbid.
  - It picks the recipient across the whole space, not the tab.
  - With no agent it starts one in a new tab.
  - Its scopes are uncommitted, last commit, vs main, plus a fourth; "last commit", not
    "last agent turn".
  - It has `"place": "none"`; its README says to replace or add a layout block.
- gfronza/herdr-app-reviewer: pastes without Enter, agent picker, scopes like
  reviewr (uncommitted, branch, last turn, commits). Tested on macOS only,
  1 star. <https://github.com/gfronza/herdr-app-reviewer>. Its send
  (`mods/reviewer/main.js:415-427` at c219fda) writes the clipboard, focuses the pane,
  calls `terminal.paste`, then clears the comments at once. It refuses a blocked agent. It
  does no draft wait and does not check that the paste landed. Its README lists limits:
  unsent comments are lost when the pane closes; last turn sees only turns that start
  while the pane is open; local machine only.
- jakub-tucek/herdr-annotator: also reads GitHub PR threads. Needs Rust, makes
  daily update checks and an optional AI request, and submits with Enter, which
  is too much. <https://github.com/jakub-tucek/herdr-annotator>
- Others, found by search (not in the grizzlybit blog, whose five picks are Agenttrail,
  herdr-nvim, Annotator, Revive and Over9k): fgiova/herdr-agent-review (Claude Code
  only), derangga/herdr-review-annotate, sangit0/herdr-code-review.

reviewr itself is a TUI plugin; upstream states it needs herdr 0.9.3 or later
and does not mention the app: <https://github.com/persiyanov/herdr-reviewr>
(also forked at <https://github.com/kaishin/herdr-reviewr>).

Possible routes: pin one community mod by commit in `home/development/herdr-app.nix`, as
`issues`, `gitlab` and `terminal-ids` are pinned there (lines 12-34, 56-59), after reading
its source; or copy the best one into `home/development/herdr-app/mods/` as an "ours" mod
and change it. The known differences above mean the first route needs changes to the send
path at least, so "adopt as is" is not on offer. Which route is open question 1.

## Affected users and systems

- The owner, in herdr-app on p620 and razer. p510 gets it only if it runs the
  app; no build or deploy there without asking.
- `home/development/herdr-app.nix` (the sync source, `managed.json` mod list,
  a key binding in `keys`) and `home/development/herdr-app/layouts/freund.json`: a mod with
  `"place": "none"` needs a layout block to open as a panel, whether it replaces `changes`
  or is added beside it.
- `docs/applications/herdr.md`: the known-gaps row for #2981 (line 394) is
  removed, and a short section on the flow is added.
- The TUI and reviewr are untouched.

## Constraints

- A mod is trusted JavaScript with command and network access
  (`herdr-app --skill`). A pinned third-party mod needs its source read first,
  and a network-free one is preferred.
- `herdr-app check <mod>` must pass, then `herdr-app shot` to look at it
  (`herdr-app --skill`). The sync only installs a mod after `check` passes.
- Mods sit in `~/.config/herdr-app`, which the app owns; changes go through
  `herdr-app-sync`, never store symlinks (`herdr-app.nix:1-6`).
- The issue says `hc send`, which waits for an unfinished human draft before it types
  (`hc --skill`) but presses Enter. A paste-only path (`terminal.paste` or herdr
  `pane.send_text`) may not inherit that wait. Whatever transport is chosen, sending must
  refuse an agent that is blocked at a permission prompt, and never use `--force` for one.
- Linux is the target. One candidate was tested on macOS only.
- AGENTS.md: explicit imports, no secrets in the store. Docs nav needs no change
  unless a page is added (then both `mkdocs.yml` and `mkdocs-full.yml`).
- Nix changes need `just test-host p620`; razer builds go via p620.

## Open questions

1. Adopt as is, adapt a community mod, or write our own? Leaning adapt: start from
   vytasgavelis/herdr-reviewer (clones `changes`, MIT, uses `git` and `hc`) and take
   gfronza's paste-only send, with the differences listed above fixed. Adopting as is
   would break the permission-prompt rule (`--force`). Decide in the spec after reading
   both sources.
2. Paste without submitting, or submit? Recommend paste only, matching reviewr,
   so the owner reads and edits before the agent acts. Verify with the chosen
   mod that no Enter is sent.
2a. What if the human already has an unfinished draft in the agent's input? Paste
   appends or garbles it; `hc send` waits. Wait, refuse, or append?
2b. What if the paste fails or cannot be confirmed (agent gone, terminal not focused)?
   When may the comments be cleared: never on failure, only after a confirmed send?
2c. Must unsent comments survive closing or restarting the pane? Gfronza loses them.
   What happens to a comment when the annotated lines change before sending: keep with
   a stale mark, or drop?
2d. Should the recipient be limited to the same tab (as in the outcome) or the whole
   space (as reviewer does), and should the mod ever start an agent?
3. Replace `changes` in the freund layout, or add the mod beside it? Recommend
   add it beside `changes` (a new layout block plus its own key) and leave `changes`
   alone, so the shipped mod keeps working and a failed mod does not remove the diff
   view. A key alone is not enough for a `"place": "none"` mod.
4. Which diff scopes are required? Recommend the four reviewr has: uncommitted,
   branch, last agent turn, commits. Check what the chosen mod covers; "last
   turn" may be the missing one.
5. Is a PR-thread feature wanted (annotator)? Recommend no: it adds network
   calls and a Rust build for something not in the issue.
6. Which key? Recommend `ctrl-shift-d` or the mod's default, checked against
   `keys.json` in `herdr-app.nix:42-51` and the TUI's `prefix+alt+d`.
