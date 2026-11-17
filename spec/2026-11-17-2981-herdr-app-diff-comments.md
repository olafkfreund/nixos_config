---
status: draft
issue: 2981
intent: intent/2026-11-17-2981-herdr-app-diff-comments.md
---

# Spec: herdr-app sends diff line comments to the agent (reviewr parity)

## Approved intent decisions

The owner approved the intent with the recommendation for every open question. Each is settled here.

| Q | Decision |
| --- | --- |
| 1 | Adapt: vendor vytasgavelis/herdr-reviewer, take gfronza's paste-only send and its last-turn code. |
| 2 | Paste only. No Enter, no `hc send`, no `--force`. |
| 2a | Send only to an idle agent. A human draft is not detectable; the paste is inserted, never replaces. |
| 2b | Comments are cleared only after the paste is confirmed on the agent's screen. Never on failure. |
| 2c | Unsent comments survive restarts (shared key). A comment whose lines changed is kept and marked. |
| 2d | Recipient is an agent in the same tab. The mod never starts an agent. |
| 3 | A new layout block and its own key, beside `changes`. `changes` is untouched. |
| 4 | Four scopes: uncommitted, branch, last agent turn, one commit. |
| 5 | No PR-thread feature. |
| 6 | `ctrl-shift-d`. Free in `keys.json` and in the layout; the TUI's `prefix+alt+d` is a different keymap. |

## Design

### Source and pinning

Two MIT sources, both read in full before this spec was written. Both are cloned under
`/tmp/claude-1000/spec-2981/` (`vr` and `gf`).

- Base: <https://github.com/vytasgavelis/herdr-reviewer> at `01e6d108a8fcc6aeaa07df5c068af59bdd642117`,
  `mods/reviewer/` (main.js 837 lines, dialog.js 165, ask.js 29, highlight.js 126, palette.js 13, icons).
  It is a clone of the shipped `changes` mod (Apache-2.0 parts), so the notices travel with it.
- Donor: <https://github.com/gfronza/herdr-app-reviewer> at `c219fda115336d3db796b81717a2f2139b223e86`,
  `mods/reviewer/turns.js` (287 lines) for the last-turn snapshots, and the paste idea at `main.js:407-427`.

The mod is vendored, not fetched, into `home/development/herdr-app/mods/reviewer/`. Reason: we change the send
path, the dialog, the scope list and the stale mark, so a `fetchFromGitHub` pin would need a patch bigger than the
file it patches. The pinned commits and the list of local changes go in a header comment of `main.js` and in
`THIRD-PARTY-NOTICES` (copied from upstream, plus gfronza's MIT line). It is added to `ours` in
`home/development/herdr-app.nix:34`, which puts it in `mods/` of the sync source and in `managed.json`. The sync
installs it only after `herdr-app check` passes (`docs/applications/herdr.md`, Sync section).

Network: upstream `reviewer` makes no `fetch` call (grep of `vr` finds `exec` of `git` only, plus `hc send`, which is
removed). The vendored mod keeps that: it runs `git` (read-only), `hc read`, and reads files under the repo.
It keeps its `"place": "none"` and gains `"focusable": true`.

Upstream `commit()` (`main.js:635-647`) runs `git add -A` then `git commit`: it stages unrelated files and runs repo
hooks. It is outside this outcome, and `changes` already covers it. The vendored mod removes `commit()`, the message
input (`main.js:142`) and the Commit button (`main.js:823`). Git use is then read-only, except the private snapshot
index of the turn scope (below).

### Layout and key

- `layouts/freund.json`: one new child of `panel-body` after `changes`: id `review`, `content.mod = "reviewer"`.
  `changes` and the `active` default stay as they are. The panel width cap (`max` 900) is not changed.
- `mods/freund-tabs/main.js:135`: add `"review"` to the list passed to `syncPanel` (next to `"issues"`, `"plans"`),
  with no button. Without it a saved `review` panel is not a registered id and restores as closed
  (`main.js:71`). Verify: open review, switch space, switch back, the panel is still `review`.
- `herdr-app.nix` `keys.global`: `"ctrl-shift-d" = "splits.review-toggle"`.
- The key is a `splits` command, as `ctrl-shift-u` is (`splits.worktree-open`). A key command reaches a mod only
  if one instance of it is mounted, and `reviewer` sits in a hidden stack child. `splits` is always mounted
  (1 px block in `status-row`). The new branch in `splits/main.js` does what freund-tabs' panel buttons do
  (`freund-tabs/main.js:141-144`): if the panel shows `review`, `layout.hide panel`; else
  `layout.select {stack: "panel-body", child: "review"}` then `layout.show {id: "panel"}`.
- No tab-bar button. Rejected as extra; the key and the palette are enough, a button can follow.

### Scopes

Four, in picker order. `reviewer.scope` cycles the first three.

| Scope | Source |
| --- | --- |
| Uncommitted | upstream "work" (`HEAD` vs working tree), unchanged. |
| Branch | upstream "branch" (merge base with `origin/HEAD`, else main, master), unchanged. |
| Last agent turn | new, from gfronza's `turns.js`. |
| Commit | upstream "commit": one commit picked from the log, against its parent. |

Upstream's "Last commit" scope is dropped: it overlaps Commit (the top of the log) and the intent asks for four.
A run of commits is not offered; Branch covers it. `SCOPES` at `main.js:58` and `scopeLabel` change accordingly.

Last agent turn:

- A turn starts when the agents of the reviewer's tab go from idle to working (`createTracker`, `workState`).
  At the start, `turns.js` writes a tree object of the working tree into a private temp folder
  (`$TMPDIR/herdr-reviewer-<tab>`) using a copy of the index. Nothing is written inside the repo. The diff is
  snapshot-start tree against the tree now, with `GIT_ALTERNATE_OBJECT_DIRECTORIES` pointing at that folder.
- The upstream load path reads the repo with four git calls, none with an environment: `--numstat`
  (`main.js:228`), `--name-status` (`main.js:239`), the per-file `git diff` (`main.js:404`), and the content read
  (`main.js:390-414`). The private tree objects resolve only with the alternates variable, so all four take the
  optional `env` (via `env VAR=... git`, the form `turns.js` already uses) and the turn scope uses them together:
  file list, statistics, per-file diff and content. The content read today special-cases only `commit`
  (`main.js:411`); for the turn scope it reads the file from the end-of-turn tree (`git cat-file` or `show` with the
  alternates), never the working tree, so a later edit does not leak into an old preview. Tests run the adapted
  reader end to end against a temp repo (see Verification); donor tests that exercise donor `git.js`/`scope.js`
  would pass while this path fails.
- Only turns that start while the mod is mounted are seen (gfronza's stated limit). A closed panel may not be
  mounted. Decision: the plan first measures whether a hidden stack child keeps running its timers. If it does not,
  a second `reviewer` block with `props: {turns: true}` goes in `status-row` next to `splits` (1 px, renders
  nothing) and owns the tracker and the snapshots; the panel reads them from a shared key. Either way, the
  scope shows "no agent turn seen since the window opened" when there is none, never an old diff.
- gfronza's `scope.js`/`git.js` are not vendored. `turns.js` needs `READ`, `alternates` and `fileKey`; the three
  are a few lines and move into `turns.js`. Its multi-repo and "this session only" parts are not taken.

### Comments, persistence and staleness

- Drafts are already in the persisted shared key `reviewer.drafts`, per repo and scope (`main.js:56`, `setComments`
  at `main.js:552-559`). That settles 2c: they survive closing the panel and restarting the app. gfronza loses them.
- Each comment stores its path, its anchor rows and `quote`, the quoted diff text as it was when written
  (`main.js:569`). Sending needs only that stored text, not the diff, so a comment made in the turn scope can be sent
  after a restart, when the snapshot tree is gone.
- Stale check (new, small). Upstream anchors keep only the two endpoint rows (`main.js:567`: `from`, `to`), so an
  edit inside the range can leave both endpoints matching, and checking only when a diff loads misses a file the
  owner never reopens. Instead, validation runs for every comment, over its whole stored `quote`, when the send
  dialog opens (and when the list is shown): for each file with comments the reader re-reads that file's current
  rows for the scope, and compares the stored quote with the rows at the anchor. No match gives the comment a
  "lines changed" label. It stays, it is not dropped, its original quote is kept as written, and the sent text
  carries "(the lines changed after this comment)" under its heading. A file that has comments but no longer
  changes stays in the list ("No longer changed, with comments", as gfronza does). A turn-scope comment from an
  earlier session cannot be re-read (the snapshot is gone): it is marked "not rechecked" and sent from its quote.
- Turn-scope drafts need a stable identity. The turn number restarts with the app, so old turn 1 and new turn 1
  would share a key. The key is `turn:<session>:<n>`, with `<session>` a random id made once per app start and
  stored with the draft. Drafts of earlier sessions are listed apart as "Earlier turns (N comments)" in the send
  dialog, off by default; the owner ticks them to include them. They are never merged into the current turn, and
  they are cleared only when sent (confirmed) or deleted by the owner.

### Send: paste only, confirmed

Replaces `dialog.js:63-80` (the `hc send` path), `dialog.js:84-98` (starting an agent) and the fallback in
`ask.js:19-28`. All three go; `knownAgents` and `tab.new` are no longer imported.

Recipient: `agents().filter(a => a.tab === focused().tab)`. None: "no agent in this tab", nothing happens. One: it is
the target. Several: the dialog's existing agent dropdown lists them (kept, but filtered by tab, not space).

Allowed: `status === "idle"` only (`agents()` already turns `done` into `idle`). `blocked`, `working` and anything
else are refused, with the status in the message and no override. `blocked` is the intent's hard rule. `working` is
stricter than the intent needs, chosen because a paste into a running turn may be taken as steering input and a
human draft cannot be seen (below). It is a one-line change to relax if the owner wants it.

Sequence, all in the mod, in this order:

1. Build the text (note, then each comment under its path and line heading with the quote, as upstream does).
   Do not close the dialog yet. The installed API (`~/.config/herdr-app/gpui-kit.d.ts:402`) says an async context
   throws once its owning script build is closed, and upstream `dialog.js:44` closes its own overlay. So the
   transaction (steps 2-6) is handed to the persistent panel: the dialog sets a shared key `reviewer.send` with the
   text and target, then closes; the panel's mounted instance runs the steps under its own `cx`. The dialog shows
   no result itself; the panel toasts. A plan step first proves the lifecycle with a harmless paste: the toast
   still appears after the dialog has closed. If that fails, the fallback is to keep the dialog open until step 6.
2. Re-read `agents()`: the target must still exist and be idle, or stop with "agent is gone" / "not idle".
3. Read the target's screen: `hc read <address> --lines 0` (the `before` text).
4. Save the clipboard text (`cx.read_from_clipboard()`), write the review with `cx.write_to_clipboard`,
   `run("pane.focus", {terminal})`, then `run("terminal.paste")`. `terminal.paste` has no arguments and pastes into
   the focused terminal (`herdr-app commands`), so the focus step is required. No `hc send`, `hc keys`, Enter or
   `--force` anywhere in the mod.
5. After a short wait (a few hundred ms, polled up to about 2 s), read the screen again (`after`).
   Confirmed only on evidence that this paste landed, never on any change. Rules, all on the diff of `after`
   against `before`:
   - A paste placeholder (Claude Code's `[Pasted text #N +M lines]`) counts only if its count of placeholders grew,
     or its `#N` is new. A placeholder already in `before` proves nothing.
   - The tail (last non-empty line of the pasted text, first 60 characters) counts only if its number of
     occurrences on screen grew. A tail already present in `before` (repeated review text, a re-send) needs a
     higher count to confirm.
   - Unrelated output that changes the screen without either signal is not confirmation.
   - Ambiguous means not confirmed: the drafts are kept.
6. Confirmed: set the `sent` shared key (the panel clears that scope's drafts), restore the saved clipboard text,
   toast `Pasted into <agent>; press Enter there to submit`.
   Not confirmed: drafts are kept, the review stays on the clipboard, toast "Could not confirm the paste; your
   comments are kept; the review is on the clipboard". The mod never retries by itself.

The check is a screen heuristic, not a protocol: herdr gives a mod no draft or input-buffer state. Hence the
pure function `confirmed(before, after, text)` lives in its own file (`paste.js`) with a unit test (below).

Draft question (2a): there is no API for the agent's draft. The pasted text is inserted at the cursor, so an
existing draft is kept, not replaced, and `pane.focus` puts the owner in that input to read it. The README section
says so. `hc send`'s draft wait is not reproduced; it would need the same missing signal.

### Docs

`docs/applications/herdr.md`: remove the known-gaps row for Issue #2981 (line 394); add a table row for `reviewer`
(near line 361) and a key row for `ctrl+shift+d` (near line 378); add a short "Diff comments" section: the flow,
the four scopes, paste-only, when a send is refused, where drafts live, and the confirm limit. No new page, so
`mkdocs.yml` and `mkdocs-full.yml` do not change. Prose lines are kept under 120 characters (markdownlint runs on
whole files at push).

## Alternatives rejected

- Adopt vytasgavelis/herdr-reviewer as is: submits with Enter and uses `hc send --force` for a working or blocked
  agent (`dialog.js:67-72`), which can type into a permission dialog. Picks the agent across the whole space, and
  starts one if none (`dialog.js:84-98`). Breaks the intent's constraints.
- Adopt gfronza/herdr-app-reviewer as is: right send idea and scopes, but 1224 lines of main.js plus a 15-file
  module set with vendored highlight.js, macOS-only tested, one star. Its send clears comments right after the
  paste with no check (`main.js:424-425`) and loses unsent comments when the pane closes. We would have to patch
  its core instead of a smaller base. Only `turns.js` is taken.
- Write our own: the diff view, folds, highlight, comment box and drafts are 800+ lines that upstream already has,
  tested on herdr-app 0.1.13. Not worth rewriting for one send path.
- Fetch a pin (`fetchFromGitHub`, as `issues` and `gitlab`): needs a patch of the send path, dialog and scopes on top
  of the fetched source. A vendored copy is the smaller, reviewable diff.
- Replace `changes` in the layout: a broken new mod would remove the diff view. Rejected per decision 3.
- `hc send` without `--force`: cannot skip Enter (`hc send --help`: "paste text and press enter").
- `hc keys` or `pane.send_text` to type text: `hc keys` sends key names, not a paste of a long text; the
  gfronza route (clipboard plus `terminal.paste`) is the one the app exposes.
- jakub-tucek/herdr-annotator (PR threads): Rust build, daily update check, optional AI request, Enter submit.
  Decision 5.
- A tab-bar button in `freund-tabs`: extra edit to another mod; the key is enough for now.
- Keeping upstream "Last commit" as a fifth scope: overlaps Commit, not asked for.
- Waiting for the human draft like `hc send`: no signal available to a mod.

## Risks

- Paste confirmation is a heuristic on screen text. A different agent UI (Codex, pi, a narrow pane that wraps the
  last line) may show neither the tail nor a placeholder: a good paste reports "could not confirm". The failure is
  safe (comments kept, review on the clipboard) but annoying. Mitigation: the owner tries each agent used on p620
  and razer; the check can be loosened per agent without touching the send order.
- `terminal.paste` pastes into the focused terminal. If `pane.focus` has not landed when it runs, the paste could go
  to the wrong pane. Mitigation: the plan's first step proves the order with a harmless target, and step 2 re-reads
  `focused()` after the focus call and pastes only if it is the target.
- A paste into an agent that has a human draft inserts at the cursor. Content is kept, but the owner may not want it
  mixed. Documented, and idle-only limits it.
- Clipboard: the review replaces the clipboard briefly; restore is best effort (text only). A non-text clipboard
  (an image) is lost. Documented.
- Last agent turn: depends on whether a hidden panel mod keeps its timers (see Scopes). Snapshots run `git add -A`
  against a copy of the index in `$TMPDIR`; a repo with `core.splitIndex` has no turn scope (gfronza's guard shows
  why). Large repos make each snapshot slow; the 250 ms sampler must not run `git` on every tick, only on the
  idle-to-working edge and when watched files change, as upstream does.
- Vendored third-party JavaScript runs with command and network access. It was read in full; upstream has no
  `fetch`. Future upstream changes are not picked up; a new pin is a deliberate re-read.
- Licence: the base derives from Herdr's Apache-2.0 `changes` mod. The notices file and the LICENSE ship with the mod.
- `herdr-app.nix` and the layout change the managed set: a bad layout could break the `freund` layout. The sync
  checks layouts with `jq`, and `ctrl+alt+shift+esc` returns to defaults.
- Hosts: p620 and razer (razer builds via p620). p510 gets the files only if it runs herdr-app; no build or deploy
  there without the owner's OK.
- Terminal programs may use `ctrl-shift-d`; the app takes it as a global key, so a program under herdr-app no longer
  sees it. Not known to be used here.

## Verification

Lead can run (no desktop, no herdr-app UI, nothing deployed):

1. Vendored source matches the pin: `git -C /tmp/claude-1000/spec-2981/vr rev-parse HEAD` equals the SHA above, and
   `diff -r` of the vendored mod against it lists only the planned changes. Same for `turns.js` against `gf`.
2. `grep -nE 'hc\(\[?"send|"--force"|"keys"|knownAgents|tab\.new|fetch\(|"add"|"commit"' \
   home/development/herdr-app/mods/reviewer/*.js` prints nothing (the snapshot code in `turns.js` is checked by hand:
   it uses a private index copy only).
3. `HERDR_APP_HOME=$(mktemp -d) herdr-app check home/development/herdr-app/mods/reviewer` exits 0. It does not need a
   running window. `herdr-app check` on `splits` too.
4. `jq . home/development/herdr-app/layouts/freund.json >/dev/null` and
   `jq '.. | objects | select(.id=="review")' ...` shows the new block under `panel-body`; `changes` is still there.
5. `node --test home/development/herdr-app/tests/` runs: `paste.test.js` for `confirmed()` (placeholder pasted, tail
   pasted, nothing changed, screen changed but text absent, wrapped last line, an old placeholder already on screen
   plus unrelated output, the tail already on screen before the paste) and the turn tracker. gfronza's own
   `tests/turns.test.js` is run from the `gf` clone with the vendored `turns.js` copied over it, which alone does not
   cover the adapted reader. Also, an end-to-end test of the adapted reader against a temp repo: snapshot, edit,
   snapshot, then the turn scope lists the right files, statistics, diffs and end-of-turn content, and a later
   working-tree edit does not change the preview. A restart test: drafts from session A, new session B turn 1,
   send; A's drafts stay separate and recoverable. A stale test: comment file A, switch to B, edit A (and edit
   the interior of a range with both endpoints unchanged), open send: both comments are marked, quotes unchanged.
6. `just check-syntax`, `just test-host p620` (local build of the home-manager closure), and razer via
   `just deploy-via-p620 razer` is not run by the lead: razer is built through p620 only on the owner's go.
   Nothing is built or deployed for p510.
7. `rg -n '#2981' docs/applications/herdr.md` shows no known-gap row; markdownlint on the file passes.
8. Review by a fresh Opus agent on `plan/` and `git diff`, as the managed instructions require.

Only the owner can check, on p620 after a deploy and on razer (each live; nothing here may be driven by an agent):

1. `ctrl-shift-d` opens and closes the review panel; `changes` still works from its own button.
2. Select one line and a range, comment each, in all four scopes. Quit and reopen the app: drafts are still there.
3. Edit a commented line, reopen: the comment shows "lines changed", is kept, and is sent with the note.
4. Send with one agent (claude-code, then Codex if used): the text appears in the input, nothing is submitted,
   comments clear only after the toast. Press Enter yourself: the agent acts.
5. Two agents in the tab: a picker appears. An agent in another tab is not offered.
6. A blocked agent (permission prompt) and a working agent are refused, with the status named, nothing typed.
7. Type half a sentence in the agent first, then send: the draft is still there with the review inserted.
8. Close the agent's pane, then send: "agent is gone", comments kept. Force a failed confirm (a pane too narrow to show
   the tail): comments kept, review on the clipboard.
9. The clipboard text you had before sending is back after a confirmed send.
10. A full agent turn that edits files, then Last agent turn shows exactly those edits.
11. `herdr-app status` reports no mod errors; `herdr-app shot` of the panel looks right (owner or agent only with the
    owner's say).
