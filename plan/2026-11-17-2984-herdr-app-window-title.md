---
status: approved
issue: 2984
spec: spec/2026-11-17-2984-herdr-app-window-title.md
coders:
  1: codex # small, tricky logic: async host lookup racing close(), title de-duplication
  2: codex # the test drives the same logic with stubs; same author as step 1 keeps them consistent
  3: coder # one table row and one doc line, mechanical
reviewers:
  - codex # independent read of the mod and its test against this plan
  # agy: out of use by owner decision (#2748)
---

# Plan: herdr-app window title with host and active space

Steps not in `coders:` are done by Claude (Opus) and are marked "(lead)": checks, commits, deploys, live checks and
the upstream comment.

## Approved decisions (carried from the spec)

1. **Premise:** the issue is out of date. Upstream shipped `setWindowTitle(title: string | null)` (PR 681, in
   `v0.1.16`, which `pkgs/herdr-app/default.nix` already pins). Last call wins across mods, `null` restores "Herdr",
   the title does not survive an app restart, call it when the title changes, not on every render. We use it and do
   not file upstream first. The PR description and the issue comment say so.
2. **Where it runs:** inside the existing `freund-tabs` mod. No new mod, no 1px block, no Nix change.
3. **Title format:** `<machine or host>: <space name>`, matching the TUI's `{hostname}: {workspace}`. The machine is
   `SpaceInfo.machine` when set (a configured name, not the remote's real hostname), else the local `hostname -s`
   from `exec("hostname", ["-s"])`. While the host is unknown (or the lookup failed) the title is the bare space name.
4. **Layouts (owner confirmed): `freund` only.** The title exists only while `freund-tabs` is loaded. Leaving `freund`
   (ctrl+shift+l) closes the View, which calls `setWindowTitle(null)`, so "Herdr" returns. Back in `freund`, `init()`
   runs again and sets the title again (this also covers an app restart).
5. **No active space, or the mod unloads:** `null` (restores "Herdr").
6. **Update rule:** `render()` calls `retitle()`; `retitle()` calls `setWindowTitle` only when the computed string
   differs from the last one set. A rename or an automatic-name change changes `space.name`, so it is covered.
   No timer, no polling.
7. **Late `exec` completion after `close()`:** a `closed` flag set in `close()` (and cleared in `init()`) makes
   `retitle()` return at once and makes the `hostname` callback do nothing, so a promise that settles during cleanup
   cannot set the old title again.
8. **Wayland:** confirmed with `hyprctl clients` on p620 after the owner's deploy. If the title does not reach
   Hyprland, stop: file it upstream; the verdict becomes "upstream-first".
9. **Reset failure blocks acceptance:** if checks O1 and O7 (the title does not return to "Herdr", or stays stale
   after the app closes) fail, do not ship. Bring the owner a design change; do not document a stale title as
   accepted and do not add a timer.
10. **Upstream comment:** one short comment on `herdrdev/herdr-app` Issue 589 after the mod works, posted only after
    the owner says so.
11. **Docs:** delete the Issue 2984 row from the known-gaps table in `docs/applications/herdr.md` and add one line to
    the managed-mods text. No `mkdocs.yml` change (no new page).

Alternatives rejected (do not revisit): new mod with a 1px block; every layout; Hyprland `windowrule` or
`renamewindow`; waiting for an upstream `window_title` setting; `SpaceInfo.machine` only; a timer.

Pinned API facts (`herdr-app` `v0.1.16`, `defaults/herdr.d.ts`): `exec(command, args?, options?)` returns
`Promise<ExecResult>` with `stdout`; `SpaceInfo` has `name`, `machine` (`null` for this computer) and `active`;
the exported View may implement `async close(cx)`.

## Steps

- **Step 1:** `home/development/herdr-app/mods/freund-tabs/main.js` lines 3, 30-37, 91-92 and a new `close()`.
  coder: codex. Change:
  - Line 3: add `setWindowTitle` and `exec` to the existing `import { ... } from "herdr"` list.
  - Add a module-level `export function titleFor(space, host)` (no app calls): `null` when `space` is falsy, else
    `${space.machine ?? host}: ${space.name}`, or just `space.name` when both `space.machine` and `host` are nullish.
    Place it after `label()` (about line 28). Keep the file's one-line `//` comment style, only why-comments.
  - In `init()` (line 31): add `this.closed = false; this.host = null; this.title = undefined;` then
    `exec("hostname", ["-s"]).then(r => { if (this.closed) return; this.host = r.stdout.trim() || null;
    this.retitle(); }).catch(() => {});`.
  - Add `retitle()`: `if (this.closed) return; const want = titleFor(this.activeSpace, this.host);
    if (want === this.title) return; this.title = want; setWindowTitle(want);`. `this.title` starts `undefined`, so
    the first call always sets, including `null`.
  - In `render()` right after line 92 (`const space = spaces().find(p => p.active);`) add
    `this.activeSpace = space; this.retitle();`.
  - Add `async close() { this.closed = true; this.title = undefined; setWindowTitle(null); }` (spec: "clears
    `this.title`"). Check the d.ts signature `close(cx)`; take `cx` only if used.
  - No other behaviour change. Do not reformat the rest of the file.
  - Check: `node --check home/development/herdr-app/mods/freund-tabs/main.js`; if it rejects ESM, use
    `node --input-type=module --check < home/development/herdr-app/mods/freund-tabs/main.js`. Then run Step 2's test.
  - Traps: the `.js` file is shipped by `herdr-app-sync`, not a store symlink; keep it ASCII-clean for `typos`;
    no change to `herdr-app.nix` or `layouts/freund.json` (explicit imports rule is unaffected); a named export
    beside the default View export must still pass `herdr-app check` (Step 4), and if it does not, drop the export
    and let the test rewrite the module text instead of importing `titleFor`.

- **Step 2:** new `home/development/herdr-app/tests/freund-tabs-title.test.mjs`. coder: codex. Change: a plain `node`
  script using `node:assert/strict`, no framework, no network. It reads `../mods/freund-tabs/main.js` as text,
  replaces the three `from "gpui-kit"`, `from "gpui-base"` and `from "herdr"` module specifiers with `data:` URL
  stubs (a stub `View` base class; stub `div`, `svg`, `image`, `h_flex`, `ScrollHandle`; a `herdr` stub that records
  `setWindowTitle` calls and exposes a controllable `exec` promise and `spaces()`), writes the rewritten source to a
  temp file under `os.tmpdir()`, and imports it. Cases:
  - T1: the `hostname` promise settles after `close()`: no further `setWindowTitle` call and `host` stays null.
  - T2: a local space gives `<host>: <name>`; a space with `machine` gives `<machine>: <name>`; host unknown (exec
    rejected) gives the bare name.
  - T3: an unchanged title makes no second call; a changed name or machine makes exactly one call.
  - T4: no active space gives one `setWindowTitle(null)`.
  - T5: `close()` calls `setWindowTitle(null)` once.
  Drive `retitle()` through an object made with `Object.create(Tabs.prototype)` after calling `init()` with a stubbed
  `localStorage`, so the file's real code is what runs. Keep the test under the mods folder's sibling `tests/` so
  `herdr-app-sync` does not copy it into the app. Print one line per case and exit non-zero on failure.
  Check: `node home/development/herdr-app/tests/freund-tabs-title.test.mjs` exits 0 and prints T1 to T5.
  Traps: do not place the file inside `mods/freund-tabs/` (the sync rsyncs the whole mod dir and
  `herdr-app check` would see it); no `.sh` file, so no shellcheck or shfmt; keep `typos` clean.

- **Step 3:** `docs/applications/herdr.md` line 401 (the Issue 2984 row; verify the line first, the spec cites 397)
  and the managed-mods text near lines 346-358. coder: coder. Change: delete the known-gaps row
  `| window title has no host or workspace | #2984 |`. In the "What is managed" area add one line: the window title is
  `<machine or host>: <space>`, set by `freund-tabs`, shows the machine name (not the remote's hostname) for a remote
  space, and is "Herdr" in other layouts. Wrap prose so lines stay at or below 120 characters; keep the surrounding
  table intact. Check: `markdownlint docs/applications/herdr.md` (the pre-push hook lints the whole file, so fix
  every finding in the file that the repo's config reports, not only the new line);
  `grep -n 2984 docs/applications/herdr.md` shows no gap row.
  Traps: in markdown prose write "Issue 2984" or use backticks; never start a line with a hash plus digits
  (the formatter turns it into an H1). `<machine or host>: <space>` must be inside backticks (no inline HTML).
  No `mkdocs.yml` or `mkdocs-full.yml` change because no page is added.

- **Step 4 (lead):** local checks, no deploy. First `git fetch origin && git merge origin/main` (a stale branch
  deploy rolls back newer main work) so the tested tree is the final tree; rerun A1 to A6 after any later merge or
  formatter edit. Run, from `/home/olafkfreund/.config/nixos-2984`:
  - A1: the `node --check` from Step 1.
  - A2: copy the mod dir to a temp dir and run `herdr-app check <temp copy>` with the installed binary
    (`/etc/profiles/per-user/olafkfreund/bin/herdr-app`), as `pkgs/herdr-app-sync/herdr-app-sync.sh` line 50 does.
    The package test fakes the checker, so only this proves the mod loads. This must not drive the app UI.
  - A3: the Step 2 test.
  - A4: `just check-syntax` and `just test-host p620` (never p510; build only, no switch).
  - A5: before the Step 5 commit, `git diff --stat $(git merge-base origin/main HEAD)` plus
    `git status --porcelain` (for untracked files) list only `freund-tabs/main.js`, the new test,
    `docs/applications/herdr.md` and the plan, spec and intent files; repeat `git diff --stat origin/main...HEAD`
    after committing.
  - A6: `markdownlint docs/applications/herdr.md plan/2026-11-17-2984-herdr-app-window-title.md`.
  Review the coders' diffs against this plan; finish anything they hand back.
  Traps: use plain `git status --porcelain` before and after each delegated step and report changes; agents never
  stage, commit or deploy; do not run `just` recipes that deploy or restart; build p620 only.

- **Step 5 (lead):** commit and push. One commit per logical change with the `(#2984)` suffix, for example
  `feat(herdr-app): window title with host and space (#2984)`; the commit body goes in a file (bus guard matches
  prose; no backticks in `git commit -m`). Plan deviations go in the same commit as the code. Before the push,
  re-run `git fetch origin`; if main moved, merge it and rerun Step 4. Pre-commit and
  pre-push formatters (trailing-whitespace, end-of-file, markdownlint, typos) may rewrite files: re-stage and check
  the result. Open the PR with `gh pr create --body-file`; link intent, spec and plan, state that the issue premise
  was out of date (Decision 1), and say which steps the coders did. After pushing, verify the remote branch head
  matches the local one.
  Traps: never commit on main or in `/home/olafkfreund/.config/nixos`; branch is `feat/2984-herdr-app-window-title`
  in this worktree; no `Co-Authored-By` omissions (use the attribution lines from the session).

- **Step 6 (owner):** the owner deploys; the lead does not (spec, Live section). The lead hands over the commands
  and stops; p510 is never deployed. Before each deploy the owner (or the lead on the owner's explicit go) reads
  `read_new("#agents:freundcloud.org.uk")`, posts what will happen and roughly how long, then runs with the flag:
  - p620: `AGENT_BUS_ANNOUNCED=1 ALLOW_BRANCH_DEPLOY=1 just p620`
  - razer: `AGENT_BUS_ANNOUNCED=1 ALLOW_BRANCH_DEPLOY=1 just deploy-via-p620 razer` (builds on p620)
  `origin/main` is already merged (Step 4). If the bus says someone else is mid-flight, wait or ask.
  Traps: Home Manager is a flake module, never `home-manager switch`; a deploy that bumps unrelated packages can
  exit 4 cosmetically on razer (see memory notes); the app owns `~/.config/herdr-app`, so the sync installs the new
  mod on the switch or the next window launch.

- **Step 7 (lead):** live checks after deploy (read-only; the lead never drives the herdr-app UI or the real
  desktop). L1: `herdr-app check` on the synced mod passes and `journalctl --user -t herdr-app-sync -n 20` shows the
  install. L2: `hyprctl clients -j | jq -r '.[] | select(.class|test("herdr";"i")) | .title'` prints
  `p620: <space>`. L3: after the owner renames the space and switches spaces, repeat L2 each time.
  The owner does these by hand and reports: O1 ctrl+shift+l away from `freund` prints "Herdr", cycling back
  restores the title; O2 quit and restart the app; O3 on razer the title shows `razer: <space>` and a remote space
  shows its machine name; O4 an unnamed space follows `cd` in its first terminal; O5 no active space prints
  "Herdr" (or record that the state is unreachable and rely on T4); O6 the bar and alt-tab show the title and, after
  O1, "Herdr"; O7 closing the app leaves no stale title. If O1, O7 or L2 fail, apply Decisions 8 and 9: stop and
  report to the owner.

- **Step 8 (lead):** after Steps 1 to 7 pass, write one short comment for `herdrdev/herdr-app` Issue 589 to a file:
  the mod works on Linux/Wayland, and a declarative `{host}: {space}` template, or a headless mod without a layout
  block, would drop the need for a hosted mod. Post it with `gh issue comment 589 -R herdrdev/herdr-app
  --body-file <file>` only after the owner says so. Also comment on Issue 2984 that the premise was out of date.
  Traps: write prose to a file and pass `--body-file`; no secrets in the text.

## Tests

- `node home/development/herdr-app/tests/freund-tabs-title.test.mjs` exits 0 and prints T1 to T5.
- `node --check` on the mod passes (A1); `herdr-app check` on a temp copy of the mod dir passes (A2).
- `just check-syntax` passes; `just test-host p620` builds (A4).
- `markdownlint docs/applications/herdr.md` is clean (A6); `just test-guards` is unaffected (no guard change).
- Live: L1 to L3 and O1 to O7 in Step 7.

## Rollback

Revert the commits on the branch (or the merged PR), then the owner rebuilds and switches the reverted configuration
(or restores a previous generation) and restarts the app. A revert alone is not enough: launch sync reads the
activated `~/.config/herdr-app-sync/source`, not the checkout, so without a switch it reinstalls the faulty mod.
`freund-tabs/main.js` is a managed file: after the switch or window launch `herdr-app-sync` copies the old version
back and backs up the new one under `~/.local/state/herdr-app-sync/backups/`.
The title then returns to "Herdr" on the next app start (the app does not
persist it). To clear a stale title at once, close and restart the app, or switch layout away from `freund` and back.
No Nix option, secret or data change is involved.
