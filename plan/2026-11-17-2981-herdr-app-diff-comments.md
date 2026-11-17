---
status: approved
issue: 2981
spec: spec/2026-11-17-2981-herdr-app-diff-comments.md
coders:
  2: coder     # vendor a pinned tree, notices, header comment: mechanical copy
  3: coder     # delete the commit, Enter, hc send and agent-start paths; change SCOPES: mechanical removal
  4: codex     # turns.js adaptation: env-aware git readers, end-of-turn content, snapshot edges: small, tricky
  5: codex     # paste.js confirmed(): count-based evidence rules and their unit tests: small, tricky logic
  6: codex     # send transaction across dialog and panel: shared-key hand-off, focus order, clipboard restore
  7: codex     # stale check over whole quotes, session-keyed turn drafts, earlier-turns list
  8: codex     # end-to-end tests against a temp repo, restart and stale tests
  9: coder     # layout block, freund-tabs list, splits branch, herdr-app.nix key and ours list: wiring
  10: codex    # only if step 1 says hidden panels stop timers: turns-only block and shared key
  11: coder    # docs/applications/herdr.md rows and a short section
reviewers:
  - codex      # independent read of each part's diff against this plan
# agy: out of use by owner decision (#2748)
---

# Plan: herdr-app sends diff line comments to the agent (reviewr parity)

Steps are numbered once. Steps marked "(lead)" are done by Claude (Opus) and are not in `coders:`: spikes, checks,
review, commits, deploys and live checks. Implementers write files only; they never stage, commit, push, deploy,
switch or restart anything. Work is in the task worktree `/home/olafkfreund/.config/nixos-2981`, never in
`~/.config/nixos`. Nothing here is built or deployed for p510.

## Approved decisions (carried from the spec)

This plan is self-contained; the spec is the record, not a reading requirement.

**Outcome.** A new mod `reviewer` in a new layout block `review`, beside `changes` (which is not touched), opened
by `ctrl-shift-d`. The owner selects a diff line or range, writes a comment, repeats, then sends all comments in
one paste into an agent in the same tab. The text is pasted, never submitted. No PR-thread feature. No tab-bar
button. The TUI and reviewr are untouched.

**Source and pinning.** Vendored, not fetched, into `home/development/herdr-app/mods/reviewer/`.

- Base: <https://github.com/vytasgavelis/herdr-reviewer> at `01e6d108a8fcc6aeaa07df5c068af59bdd642117`,
  `mods/reviewer/` (main.js 837 lines, dialog.js 165, ask.js 29, highlight.js 126, palette.js 13, icons, mod.json).
  A clone of the shipped Herdr `changes` mod (Apache-2.0 parts), so the notices travel with it.
- Donor: <https://github.com/gfronza/herdr-app-reviewer> at `c219fda115336d3db796b81717a2f2139b223e86`,
  `mods/reviewer/turns.js` (287 lines) and the paste idea at `main.js:407-427`. Only `turns.js` is taken; `READ`,
  `alternates` and `fileKey` (a few lines) move into it. Its `scope.js` and `git.js`, multi-repo and "this session
  only" parts are not taken.
- Both clones are at `/tmp/claude-1000/spec-2981/vr` and `/tmp/claude-1000/spec-2981/gf`. If they are gone,
  re-clone and check out the pinned SHAs before copying.
- The pins and the list of local changes go in a header comment of `main.js` and in `THIRD-PARTY-NOTICES`
  (upstream's, plus gfronza's MIT line). The upstream LICENSE ships with the mod.
- The mod is added to `ours` in `home/development/herdr-app.nix:33`. The sync installs it only after
  `herdr-app check` passes.
- Network-free: the mod runs `git` (read-only), `hc read`, and reads files under the repo. `mod.json` keeps
  `"place": "none"` and gains `"focusable": true`.
- Removed from upstream: `commit()` (`main.js:635-647`, it runs `git add -A` and hooks), the message input
  (`main.js:142`), the Commit button (`main.js:823`). Git is then read-only, except the private snapshot index of
  the turn scope.

**Layout and key.**

- `layouts/freund.json`: one new child of `panel-body` after `changes`: id `review`, type `block`,
  `content.mod = "reviewer"`. `changes`, the `active` default and the panel width cap stay.
- `mods/freund-tabs/main.js:135`: add `"review"` to the list given to `syncPanel` (next to `"issues"`, `"plans"`),
  no button. Without it a saved `review` panel restores as closed.
- `herdr-app.nix` `keys.global`: `"ctrl-shift-d" = "splits.review-toggle"`. A key command reaches only a mounted
  mod instance, and `reviewer` sits in a hidden stack child, so the key goes to `splits` (always mounted).
- `splits/main.js`: a `review-toggle` branch next to `worktree-open`. If the panel shows `review`:
  `run("layout.hide", { id: "panel" })`. Else `run("layout.select", { stack: "panel-body", child: "review" })`
  then `run("layout.show", { id: "panel" })` (what `freund-tabs/main.js:141-144` does for its buttons).

**Scopes.** Four, in picker order; `reviewer.scope` cycles the first three. `SCOPES` (`main.js:58`) and
`scopeLabel` change.

| Scope | Source |
| --- | --- |
| Uncommitted | upstream "work" (`HEAD` vs working tree), unchanged. |
| Branch | upstream "branch" (merge base with `origin/HEAD`, else main, master), unchanged. |
| Last agent turn | new, from gfronza's `turns.js`. |
| Commit | upstream "commit": one commit from the log, against its parent. |

Upstream's "Last commit" scope is dropped. No run-of-commits scope.

**Last agent turn.**

- A turn starts when the agents of the reviewer's tab go idle to working (`createTracker`, `workState`). At the
  start, `turns.js` writes a tree object of the working tree into a private folder
  (`$TMPDIR/herdr-reviewer-<tab>`) using a copy of the index. Nothing is written inside the repo. The diff is
  snapshot-start tree against the tree now, with `GIT_ALTERNATE_OBJECT_DIRECTORIES` pointing at that folder.
- The upstream load path makes four git reads with no environment: `--numstat` (`main.js:228`), `--name-status`
  (`main.js:239`), the per-file `git diff` (`main.js:404`), and the content read (`main.js:390-414`). All four take
  an optional `env` (via `env VAR=... git`, the form `turns.js` uses) and the turn scope uses them together. For
  the turn scope the content read takes the file from the end-of-turn tree (`git cat-file` or `show` with the
  alternates), never the working tree, so a later edit does not leak into an old preview. Today only `commit` is
  special-cased (`main.js:411`).
- Only turns that start while the mod is mounted are seen. Step 1 measures whether a hidden stack child keeps
  running its timers. If not, a second `reviewer` block with `props: {turns: true}` goes in `status-row` next to
  `splits` (1 px, renders nothing), owns the tracker and snapshots, and the panel reads them from a shared key.
  Either way the scope says "no agent turn seen since the window opened" when there is none, never an old diff.
- Snapshots run on the idle-to-working edge and when watched files change, never on every 250 ms tick. A repo with
  `core.splitIndex` has no turn scope.

**Comments, persistence, staleness.**

- Drafts already live in the persisted shared key `reviewer.drafts`, per repo and scope (`main.js:56`,
  `setComments` at `main.js:552-559`). They survive closing the panel and restarting the app.
- Each comment stores path, anchor rows and `quote` (the quoted diff text as written, `main.js:569`). Sending
  uses only that stored text, so a turn-scope comment can be sent after a restart.
- Stale check (new): validation runs for every comment, over its whole stored `quote`, when the send dialog opens
  and when the list is shown. For each file with comments the reader re-reads that file's current rows for the
  scope and compares the stored quote with the rows at the anchor. No match: a "lines changed" label; the comment
  stays, its quote is kept as written, and the sent text carries "(the lines changed after this comment)" under
  its heading. A file with comments that no longer changes stays listed ("No longer changed, with comments"). A
  turn-scope comment from an earlier session cannot be re-read: marked "not rechecked", sent from its quote.
- Turn-scope drafts use the key `turn:<session>:<n>`, `<session>` a random id made once per app start and stored
  with the draft. Drafts of earlier sessions are listed apart in the send dialog as "Earlier turns (N comments)",
  off by default, ticked by the owner to include. Never merged into the current turn; cleared only when sent
  (confirmed) or deleted by the owner.

**Send: paste only, confirmed.** Replaces `dialog.js:63-80` (the `hc send` path), `dialog.js:84-98` (starting an
agent) and the fallback in `ask.js:19-28`; `knownAgents` and `tab.new` are no longer imported.

- Recipient: `agents().filter(a => a.tab === focused().tab)`. None: "no agent in this tab", nothing happens. One:
  the target. Several: the dialog's agent dropdown (filtered by tab, not space). The mod never starts an agent.
- Allowed only when `status === "idle"` (`agents()` already maps `done` to `idle`). `blocked`, `working` and
  anything else are refused with the status in the message and no override. (`working` is stricter than the intent
  needs; it is a one-line relax if the owner asks.)
- Sequence, all in the mod:
  1. Build the text (note, then each comment under its path and line heading with the quote, as upstream does).
     An async `cx` throws once its owning script build is closed (`~/.config/herdr-app/gpui-kit.d.ts:402`) and the
     dialog closes its own overlay (`dialog.js:44`), so the dialog sets a shared key `reviewer.send` with the text
     and target and closes. The panel's mounted instance runs steps 2 to 6 under its own `cx` and toasts. The
     fallback, if step 1 of this plan shows the toast does not survive the dialog closing: keep the dialog open
     until step 6.
  2. Re-read `agents()`: the target must still exist and be idle, else "agent is gone" / "not idle".
  3. Read the target screen: `hc read <address> --lines 0` (the `before` text).
  4. Save the clipboard text (`cx.read_from_clipboard()`), `cx.write_to_clipboard` the review,
     `run("pane.focus", {terminal})`, re-read `focused()` and paste only if it is the target, then
     `run("terminal.paste")` (no arguments, pastes into the focused terminal). No `hc send`, `hc keys`, Enter or
     `--force` anywhere in the mod.
  5. Wait a few hundred ms, poll up to about 2 s, read the screen again (`after`). Confirmed only on evidence this
     paste landed, from the diff of `after` against `before`: a paste placeholder (Claude Code
     `[Pasted text #N +M lines]`) counts only if the placeholder count grew or its `#N` is new; the tail (last
     non-empty line of the text, first 60 characters) counts only if its occurrences on screen grew; unrelated
     output is not confirmation; ambiguous means not confirmed.
  6. Confirmed: the panel clears exactly the comment ids named in the request, restore the saved clipboard
     text, toast `Pasted into <agent>; press Enter there to submit`. Not confirmed: drafts kept, review stays on
     the clipboard, toast "Could not confirm the paste; your comments are kept; the review is on the clipboard".
     No automatic retry.
- `confirmed(before, after, text)` is a pure function in `paste.js` with a unit test.
- An unfinished human draft cannot be detected. The paste inserts at the cursor, so a draft is kept, not replaced.
  `hc send`'s draft wait is not reproduced.

**Docs.** `docs/applications/herdr.md`: remove the known-gaps row for Issue #2981 (now line 398); add a table row
for `reviewer` (near line 361) and a key row for `ctrl+shift+d` (near line 378); add a short "Diff comments"
section: the flow, four scopes, paste-only, when a send is refused, where drafts live, the confirm limit, the
clipboard-restore limit (text only). No new page, so `mkdocs.yml` and `mkdocs-full.yml` do not change.

**Risks to keep in view.** Paste confirmation is a screen heuristic (other agent UIs may show neither tail nor
placeholder: safe failure, comments kept). `terminal.paste` goes to the focused terminal, so the focus order must
be proved. Vendored JavaScript runs with command access; it was read in full and has no `fetch`. A bad layout can
break the `freund` layout; the sync checks layouts with `jq`, and `ctrl+alt+shift+esc` returns to defaults.
`ctrl-shift-d` becomes a global key, so a program under herdr-app no longer sees it.

## Steps

- **Step 1 (lead):** live spike, no repo edits. Needs the owner's say before anything touches a window, because an
  agent may not drive the real desktop or herdr-app UI. Ask the owner to run, or to approve, two probes with a
  scratch mod under `$HERDR_APP_HOME` (never in the repo) and a harmless target pane running `cat`.
  (a) Lifecycle: a dialog sets a shared key and closes; the mounted panel instance reacts to the key under its own
  `cx`, runs `cx.write_to_clipboard`, `run("pane.focus", {terminal})`, a `focused()` re-read,
  `run("terminal.paste")`, then toasts. Record: does the toast appear after the dialog has closed, does the paste
  reach the focused `cat` pane and not another. (b) Timers: does a `reviewer` block in a hidden `panel-body` stack
  child keep its `setInterval` and `cx.spawn` loops running while hidden. Record both answers in the PR
  description and here. Result (a) fails: step 6 keeps the dialog open until its step 6. Result (b) fails: do
  step 10. Check: the owner reports the observations; `herdr-app status` shows no mod errors.
  Traps: no `hc send`, `hc keys` or Enter in the probe; the probe never targets a real agent pane; no deploy.
- **Step 2:** `home/development/herdr-app/mods/reviewer/`: copy `mods/reviewer/` from
  `/tmp/claude-1000/spec-2981/vr` at the pinned SHA (`git -C ... rev-parse HEAD` must print
  `01e6d108a8fcc6aeaa07df5c068af59bdd642117`): `main.js`, `dialog.js`, `ask.js`, `highlight.js`, `palette.js`,
  the SVG icons (`changes`, `check`, `chevron-down`, `comment`, `copy`, `fold-vertical`, `unfold-vertical`),
  `mod.json`; the pinned base has no `tree.js`. Copy `LICENSE` and `THIRD-PARTY-NOTICES` from the repo root of
  `vr`, not the mod folder, into the mod folder (upstream's plus a line for
  gfronza's MIT licence and the Herdr Apache-2.0 notice for the `changes` parts). Set `"focusable": true` in
  `mod.json`, keep `"place": "none"`. Put the header comment at the top of `main.js` with both pinned SHAs and a
  list of local changes (filled in as steps 3 to 7 land). Check:
  `git -C /tmp/claude-1000/spec-2981/vr rev-parse HEAD` and
  `diff -r /tmp/claude-1000/spec-2981/vr/mods/reviewer home/development/herdr-app/mods/reviewer`
  lists only the files added or changed here. Traps: explicit paths only, no `readDir`; files stay below the
  120-character prose limit only where they are `.md`; pre-commit `json-format` and `end-of-file` apply.
- **Step 3:** `home/development/herdr-app/mods/reviewer/main.js`, `dialog.js`, `ask.js`: delete `commit()`
  (`main.js:635-647`), the message input (`main.js:142`) and the Commit button (`main.js:823`); delete the
  `hc send` path (`dialog.js:63-80`), the agent start (`dialog.js:84-98`), the `ask.js:19-28` fallback; drop the
  `knownAgents` and `tab.new` imports. Change `SCOPES` (`main.js:58`) and `scopeLabel` to the four scopes in
  picker order and make `reviewer.scope` cycle the first three. Drop upstream "Last commit". Leave the send
  action as a stub that builds the text and does nothing until step 6. Check:
  `grep -nE 'hc\(\[?"send|"--force"|"keys"|knownAgents|tab\.new|fetch\(|"add"|commit\(|git add|git commit' *.js`
  run inside the mod folder prints nothing (no match is the pass, and `grep` exits 1 then; it does not match the
  retained Commit scope, which is read-only and reviewed by hand; the `turns.js` private-index `add -A` is
  reviewed in step 4), and
  `HERDR_APP_HOME=$(mktemp -d) herdr-app check home/development/herdr-app/mods/reviewer` exits 0.
  Traps: git must be read-only after this step; no Enter or `--force` anywhere.
- **Step 4:** `home/development/herdr-app/mods/reviewer/turns.js` (new), `main.js` load path: copy `turns.js` from
  `/tmp/claude-1000/spec-2981/gf` at `c219fda115336d3db796b81717a2f2139b223e86`; move the few lines of `READ`,
  `alternates` and `fileKey` into it; drop the multi-repo and "this session only" parts. Give the four upstream
  readers (`--numstat` `main.js:228`, `--name-status` `main.js:239`, per-file `git diff` `main.js:404`, content
  read `main.js:390-414`) an optional `env` passed as `env VAR=... git`, and use it for the turn scope. The turn
  scope reads content from the end-of-turn tree with `git cat-file`/`show` plus the alternates, never the working
  tree. Add the turn scope to the picker with the "no agent turn seen since the window opened" empty state.
  Snapshots only on the idle-to-working edge and when watched files change; no `core.splitIndex` repos. The
  snapshot code uses a private index copy under `$TMPDIR/herdr-reviewer-<tab>` and writes nothing in the repo.
  The hidden-panel model chosen by step 1 (b) is built here, not later: if hidden children keep timers, the panel
  owns the tracker; if not, the turns-only block of step 10 is added now and the panel reads its shared key. Check:
  the tracker tests are written with the code in `tests/turns.test.js` (step 8 extends them) and run with
  `node --test home/development/herdr-app/tests/turns.test.js`; and by hand
  `grep -n 'git' home/development/herdr-app/mods/reviewer/turns.js` shows `add -A` only with `GIT_INDEX_FILE`
  set to the copy. Traps: a repo write here is a bug; never run `git add` against the real index. Only one snapshot
  owner runs.
- **Step 5:** `home/development/herdr-app/mods/reviewer/paste.js` (new) and
  `home/development/herdr-app/tests/paste.test.js` (new): pure `confirmed(before, after, text)` with the count
  rules from the spec (placeholder count grew or new `#N`; tail occurrences grew; unrelated output is not
  confirmation; ambiguous is false). Cases: placeholder pasted, tail pasted, nothing changed, screen changed but
  text absent, wrapped last line, an old placeholder already on screen plus unrelated output, the tail already on
  screen before the paste. Check: `node --test home/development/herdr-app/tests/paste.test.js`.
  Traps: no I/O in `paste.js`; tests use `node:test` only, no new dependency.
- **Step 6:** `home/development/herdr-app/mods/reviewer/dialog.js`, `main.js`: the send transaction. The dialog
  validates recipient (tab filter, idle only, the status named in a refusal), sets the shared key
  `reviewer.send` with `{id, text, target, repo, scope, drafts}` and closes. `id` is a fresh random id per
  request; `drafts` lists the draft keys and the comment ids actually included (the current scope's, plus the
  ticked earlier-turn drafts). The panel consumes the request: it records `id` as handled in the persisted shared
  key `reviewer.handled` and clears `reviewer.send` before sequence step 2, so reopening or restarting never
  replays it; a request whose `id` is already handled is dropped. On confirmation it clears only those comment
  ids from those draft keys, not whatever the panel shows now, and the upstream global `reviewer.sent` handler
  (`main.js:759-761`, which clears the displayed comments) is removed. The panel's mounted instance runs sequence
  steps 2 to 6
  under its own `cx` using `confirmed()` from step 5, clears the confirmed comment ids only then,
  restores the clipboard, and toasts the three messages. Tests in step 8: switch repo or scope during
  confirmation, including with earlier-turn drafts ticked (the unsent comments stay), and start with an old
  `reviewer.send` request present (nothing is pasted or cleared). If step 1 (a) failed, keep the dialog open and run the
  same sequence in it. Check: `grep` from step 3 still prints nothing and `herdr-app check` on the mod exits 0;
  the live behaviour is checked by the owner in step 13. Traps: never close the dialog's own build before a
  needed `cx` call finishes in the fallback; no retry loop; comments are never cleared on failure.
- **Step 7:** `home/development/herdr-app/mods/reviewer/main.js`, `dialog.js`: the stale check and turn identity.
  On opening the send dialog and the list, re-read each commented file's rows for the scope and compare the whole
  stored quote with the rows at the anchor; label "lines changed" or "not rechecked"; keep the quote as written;
  add the "(the lines changed after this comment)" line to the sent text; keep "No longer changed, with
  comments". Turn drafts get the key `turn:<session>:<n>` with a random `<session>` made once per app start and
  stored with the draft; earlier sessions' drafts are listed as "Earlier turns (N comments)", off by default, and
  are never merged. Check: `node --test home/development/herdr-app/tests/*.test.js` (the stale test is written with
  this step in `tests/stale.test.js`) and `herdr-app check` on the mod. Traps: a comment is never dropped by the stale
  check; a persisted draft key
  stays backward compatible with plain scope keys.
- **Step 8:** `home/development/herdr-app/tests/` (new): `turns.test.js` (tracker, run gfronza's own
  `tests/turns.test.js` from the `gf` clone with the vendored `turns.js` copied over it as an extra check); an
  end-to-end test of the adapted reader against a temp repo: snapshot, edit, snapshot, the turn scope lists the
  right files, statistics, diffs and end-of-turn content, and a later working-tree edit does not change the
  preview; a restart test (drafts from session A, new session B turn 1, send, A's drafts stay separate and
  recoverable); a stale test (comment file A, switch to B, edit A, and edit the interior of a range with both
  endpoints unchanged, open send, both comments are marked, quotes unchanged). Check:
  `node --test home/development/herdr-app/tests/*.test.js` all pass; with the panel hidden and then opened,
  exactly one snapshot owner runs. Traps: temp repos under `mktemp -d`, never the
  worktree; a donor test of donor `git.js`/`scope.js` passing proves nothing about the adapted path, so the
  end-to-end test is required.
- **Step 9:** wiring in four files.
  `home/development/herdr-app/layouts/freund.json` (child of `panel-body`, after `changes` at about lines 175-181):
  add `{ "id": "review", "type": "block", "content": { "mod": "reviewer" } }`.
  `home/development/herdr-app/mods/freund-tabs/main.js:135`: add `"review"` to the `syncPanel` list.
  `home/development/herdr-app/mods/splits/main.js` (the command loop near line 35): add a `review-toggle` branch
  as specified above, then `continue`.
  `home/development/herdr-app.nix`: add `"reviewer"` to `ours` (line 34) and
  `"ctrl-shift-d" = "splits.review-toggle";` to `keys.global` (after `ctrl-shift-i`). Check:
  `jq . home/development/herdr-app/layouts/freund.json >/dev/null`,
  `jq '.. | objects | select(.id=="review" or .id=="changes")' home/development/herdr-app/layouts/freund.json`
  shows both, `HERDR_APP_HOME=$(mktemp -d) herdr-app check home/development/herdr-app/mods/splits` and the same
  for `freund-tabs` and `reviewer` exit 0, `just check-syntax`. Traps: AGENTS.md explicit imports, no `readDir`;
  nix edits follow the file's existing attribute style (nixpkgs-fmt); `managed.json` takes `ours` as is, so no
  second edit; do not touch `mkdocs.yml` or `mkdocs-full.yml`.
- **Step 10 (only if step 1 (b) failed; its work is done inside step 4, execute it there):**
  `home/development/herdr-app/layouts/freund.json` and `reviewer`: add a
  second `reviewer` block with `props: {turns: true}` in `status-row` next to `splits`, 1 px, rendering nothing,
  owning the tracker and snapshots and publishing them through a shared key the panel reads. Skip this step, and
  note "not needed" in the PR, when step 1 (b) showed hidden children keep running. Check: `jq` as in step 9, the
  `reviewer` check, and a test that the panel reads real snapshots from the tracker's key, hidden then opened. Traps:
  it must render nothing and must not
  start a second snapshot owner while the panel is mounted.
- **Step 11:** `docs/applications/herdr.md`: delete the known-gaps row for Issue #2981 (line 398); add the
  `reviewer` row to the mods table (near line 361) and the `ctrl+shift+d` row to the keys table (near line 378);
  add the short "Diff comments" section as specified above. Check: `rg -n '#2981' docs/applications/herdr.md`
  shows no known-gap row, and `markdownlint docs/applications/herdr.md` (or `pre-commit run markdownlint --files
  docs/applications/herdr.md`) passes. Traps: markdownlint lints whole files at push, prose lines at most 120
  characters; write `Issue #2981` in prose, never a line starting with a hash and digits; no inline HTML outside
  backticks.
- **Step 12 (lead):** verification before any deploy. In the worktree: the full checklist, inlined: (1) pin match
  (`diff -r` against `vr` lists only planned changes; `turns.js` against `gf`), (2) the forbidden-pattern
  `grep` from step 3, (3) `herdr-app check` on `reviewer`, `splits` and `freund-tabs` with a temp `HERDR_APP_HOME`,
  (4) the `jq` checks of step 9, (5)
  `node --test home/development/herdr-app/tests/*.test.js`, (6) `just check-syntax` and `just test-host p620`, (7) the
  `rg` and
  markdownlint check of step 11. Then `git status --porcelain` shows only the planned files. Run this after merging
  `origin/main` (step 13 does the
  merge first) and record the tested commit. Check: every command exits as expected: builds, `node --test`,
  `herdr-app check`, `jq` and `markdownlint` exit 0; the forbidden-pattern and `rg` absence checks exit 1 because
  nothing matches; `diff -r` exits 1 because the planned changes differ.
  Traps: `just test-host p620` builds the full p620 system toplevel (it takes a while); no p510 build; pre-commit and
  pre-push formatters (nixpkgs-fmt, json-format, markdownlint, typos, end-of-file) may rewrite files, so rerun
  until clean; no shellcheck target here unless a shell script was added (none planned).
- **Step 13 (lead):** review, commits, deploy, live checks. Review with a fresh agent on `model: "opus"`, given
  only this plan path and `git diff`; run Codex read-only through `second-opinion` as `reviewers:` names, and
  check `git status --porcelain` before and after. Commit per step on the task branch with Conventional Commits
  and `(#2981)`, naming the plan step in each message and which steps Codex or the coder did; update `plan/` in
  the same commit as any deviation. Merge `origin/main` into the branch first, then run step 12 on the merged commit
  (a stale branch deploy rolls back newer work), and deploy exactly the commit that step 12 tested; if the branch
  moves after that, repeat step 12. Read `read_new("#agents:freundcloud.org.uk")`, post the deploy and its duration,
  then
  deploy p620 with `AGENT_BUS_ANNOUNCED=1 ALLOW_BRANCH_DEPLOY=1 just p620`. Razer only on the owner's go:
  `AGENT_BUS_ANNOUNCED=1 ALLOW_BRANCH_DEPLOY=1 just deploy-via-p620 razer`. Never build or deploy p510. After the
  deploy, hand the owner this live checklist (ctrl-shift-d toggle, comments in four scopes and
  restart, stale label, send to one and two agents, blocked and working refusals, draft kept, agent gone and
  failed confirm, clipboard restored, a full turn shows exactly its edits, `herdr-app status` clean and a
  `herdr-app shot` only with the owner's say); an agent does not drive these. Open the PR linking intent, spec
  and plan, with the step 1 results. Check: `git log` shows one approval commit for this plan before step 2,
  `just test-host p620` passed, and the PR description links all three files.
  Traps: write commit and PR prose to a file and pass `--body-file`/`-F` (the bus guard greps command text, and no
  backticks inside `git commit -m`); a deploy with a changed unit may exit 4 as a cosmetic switch result on razer;
  after a push, compare the remote branch head; return the shared checkout to `main` if it was moved.

## Tests

- Unit: `node --test home/development/herdr-app/tests/*.test.js` runs `paste.test.js`, `turns.test.js`, the end-to-end
  reader test against a temp repo, the restart test and the stale test (steps 5, 7, 8, and 10 if done).
- Donor: gfronza's `tests/turns.test.js`, run from the `gf` clone with the vendored `turns.js` copied over it.
- Static: the forbidden-pattern `grep`, `herdr-app check` on `reviewer`, `splits` and `freund-tabs`, `jq` on the
  layout, `just check-syntax`, `just test-host p620`, markdownlint on the docs file.
- Owner live checks on p620 and razer after deploy (step 13); nothing here may be driven by an agent.

## Rollback

- Before deploy: drop the branch commits; nothing is installed.
- After deploy: revert the PR on main and deploy p620 (and razer) again. A revert alone leaves the new key and mod
  installed: the sync merges keys, keeping those absent from the reverted source, and does not prune removed mods.
  Per host, pause the sync first (remove `~/.config/herdr-app-sync/source`) and close the app, delete the
  introduced `reviewer` mod folder and the `ctrl-shift-d` entry in `keys.json`, copy back the pre-change backups
  from `~/.local/state/herdr-app-sync/backups/<time>/` oldest first, delete managed items that have no backup,
  delete `manifest.json`, and start the app, as `docs/applications/herdr.md` (Sync, backups and rollback) says.
- At runtime a broken layout is escaped with `ctrl+alt+shift+esc` (default layout and keys). `changes` is never
  edited, so the diff view keeps working if `reviewer` fails.
- Drafts persist in the shared key `reviewer.drafts`; a revert leaves them unread and harmless.
