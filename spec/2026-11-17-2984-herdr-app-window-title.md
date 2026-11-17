---
status: approved
issue: 2984
intent: intent/2026-11-17-2984-herdr-app-window-title.md
---

# Spec: herdr-app window title with host and active space

## Approved intent decisions

The owner approved the intent with "use your recommendation for this". Each recommendation is a decision:

1. **Premise:** the issue is out of date. Upstream shipped `setWindowTitle` (PR #681, in `v0.1.16`). We use it
   and do not file upstream first. The PR description and the issue comment say so.
2. **Where it runs:** inside `freund-tabs`. No new mod, no 1px block.
3. **Remote space:** `SpaceInfo.machine` when set, else the local `hostname -s`. The docs call it the machine name.
4. **Layouts:** the intent asks the question (question 4) but gives no recommendation. This spec proposes: the title
   exists only while `freund-tabs` is loaded, and leaving `freund` restores "Herdr" (see Design). The owner confirms
   this scope when approving the spec.
5. **No active space or mod unloads:** `null`, which restores "Herdr".
6. **Wayland:** confirmed by `hyprctl clients` on p620 after a test build. If the title does not reach Hyprland, stop:
   file it upstream and the verdict becomes "upstream-first".
7. **Upstream comment:** one short comment on `herdrdev/herdr-app` Issue #589, after the mod works.

## Facts this design rests on

Checked on 2026-11-17 against `herdrdev/herdr-app` tag `v0.1.16` (sha 034f8b85f7e6bb71f8ff55cb4a80c548b2578c0f),
file `defaults/herdr.d.ts` (fetched with `gh api`, kept in `/tmp/claude-1000/spec-2984/herdr.d.ts`):

- Line 299: `setWindowTitle(title: string | null): null`. Last call wins across mods, `null` restores "Herdr",
  it does not outlive the app, call it when the title changes, not on every render (lines 296-298).
- Line 14: `exec(command, args?, options?): Promise<ExecResult>`. It runs with the user's real environment.
- Lines 123-133: `SpaceInfo.name` is the given name, else the first terminal's repo or folder. `machine` is the
  `hc machine ls` name, `null` for this computer.
- Line 442: the exported View "may implement async close(cx) for bounded final cleanup".
- Upstream Issue #589 is open with one comment (2026-11-17). `pkgs/herdr-app/default.nix` line 27 pins `0.1.16`.

Local code:

- `home/development/herdr-app/mods/freund-tabs/main.js` line 92 already does
  `const space = spaces().find(p => p.active)` in `render()`, which re-runs when spaces change.
- `layouts/freund.json` hosts `freund-tabs` as block `tabs` (about line 84). `herdr-app.nix` line 33 lists it in `ours`.
- The Herdr TUI sets `{hostname}: {workspace}` in `home/development/herdr.nix` lines 152-155. We match that format.

## Design

One file changes: `home/development/herdr-app/mods/freund-tabs/main.js`. Plus the docs.

1. Import `setWindowTitle` and `exec` from `"herdr"` (the import on line 3 already exists for the other calls).
2. In `init()`: `this.host = null; this.title = undefined;` and start
   `exec("hostname", ["-s"]).then(r => { if (this.closed) return; this.host = r.stdout.trim() || null;
   this.retitle(); }).catch(() => {})`. Also set `this.closed = false` in `init()`. The `.catch` leaves `host` null;
   the title then falls back to the space name alone. The `closed` check stops a late completion from setting the
   old title again after `close()` reset it (see Risks).
3. A pure function `titleFor(space, host)` (module level, no app calls) computes the wanted title. A method
   `retitle()` returns at once when `this.closed`, else calls `setWindowTitle` only when the result differs from
   `this.title`:
   - Active space `s` (stored as `this.activeSpace` by `render()`).
   - No active space: `null`.
   - Else `${s.machine ?? this.host}: ${s.name}`, or just `s.name` while the host is unknown.
   - Equal to `this.title`: do nothing (upstream's "not on every render" rule).
4. `render()` calls `this.retitle()` after it reads `space` (after line 92). It runs on every render but only calls
   the app when the string changes, so it also covers a rename and an automatic-name change (both change `s.name`).
5. `async close()` sets `this.closed = true`, calls `setWindowTitle(null)` and clears `this.title`.
   When the layout switches away from `freund`
   (ctrl+shift+l, `docs/applications/herdr.md` line 376) the View closes, so "Herdr" returns outside `freund`.
   Back in `freund`, `init()` runs again, so the title is set again (also covers an app restart).
6. If a space's `machine` is set, the title shows that machine name, not the remote's `hostname -s`.

Docs (`docs/applications/herdr.md`): delete the Issue #2984 row from the known-gaps table (line 397) and add one
line to the managed-mods text: the window title is `<machine or host>: <space>`, set by `freund-tabs`, "Herdr" in
other layouts. No `mkdocs.yml` change (no new page).

No setting, no template, no new mod, no Nix change. `herdr-app-sync` ships the file as it ships the other managed
mods, after `herdr-app check` passes.

## Alternatives rejected

- **New mod with a 1px block:** adds a mod, a layout block and an `ours` entry. PR #681 calls the 1px block
  "a little janky". `freund-tabs` is already placed and already reads the active space.
- **Cover every layout:** needs the title set from a mod hosted by every layout, or a change to shipped layouts,
  which the app rewrites on start (Issue #2978 spec). No cheaper way exists, so this spec
  proposes "freund only" (see decision 4).
- **Hyprland `windowrule` / `renamewindow`:** fixed titles, cannot follow the active space.
- **Wait for upstream `window_title` setting (Issue #589):** open, no implementation known. The API exists now.
- **Use `SpaceInfo.machine` only:** it is `null` for local spaces, so the local host needs `hostname -s` anyway.
- **Poll the title on a timer:** the render path already fires on every relevant change.

## Risks

- **`close()` may not run on a layout switch**, or not before the next layout draws. Then "Herdr" does not return.
  A stale host/space label recreates the identification problem, so reset failure blocks acceptance: the mod does not
  ship until checks O1 and O7 pass. If they fail, stop and bring the owner a design change (for example the title in
  every layout); do not document a stale title as accepted and do not add a timer.
- **Late `exec` completion after close:** `close()` only resets the title, so a `hostname` promise that settles during
  cleanup could call `retitle()` and set the old space title again. Upstream drains JS jobs inside `start_close`
  (`scheduler::drain_runtime_jobs`, `vendor/gpui-kit/crates/shell/src/engine/quickjs/lifecycle.rs` lines 44-77 at
  `034f8b85`) before the generation is released, so this is source-supported, not reproduced. The `closed` flag in
  Design 2 and 3 closes it; test T1 covers it.
- **Wayland unverified upstream:** PR #681 was tested on macOS only. Check L2 decides.
- **Remote host name:** `machine` is a configured name, not the real remote hostname. Documented.
- **`hostname -s` lag:** the first title may show the space name alone for a moment. Harmless.
- **Another mod calling `setWindowTitle`:** last call wins. None of ours does today.
- **Render-time side effect:** `retitle()` is idempotent and guarded, but a call inside `render()` is unusual.
  If upstream objects, move it to a `spaces()` change hook, if one exists (not found in `v0.1.16` d.ts).
- Layout-wide loss: none. The mod change is local to a managed file; `herdr-app-sync` backs up the old copy.

## Verification

Agent, no deploy:

- **A1** `node --check home/development/herdr-app/mods/freund-tabs/main.js` (module syntax, imports unresolved is
  fine; if `--check` rejects ESM, use `node --input-type=module --check < file`).
- **A2** The real mod check, as `herdr-app-sync` runs it (`pkgs/herdr-app-sync/herdr-app-sync.sh` line 50):
  `herdr-app check <temp copy of the mod dir>` with the installed binary. The package test
  (`pkgs/herdr-app-sync/test.sh`) fakes the checker, so it does not prove this.
- **A3** One small behavioral test, no new framework: a plain `node` assert script that imports `titleFor` and drives
  `retitle()` and `close()` with a stubbed `setWindowTitle`. It covers:
  - **T1** a `hostname` completion that settles after `close()` makes no `setWindowTitle` call;
  - **T2** a local space gives `<host>: <name>`; a space with `machine` gives `<machine>: <name>`; host unknown gives
    the bare name;
  - **T3** an unchanged title makes no second call; a changed name or machine makes one call;
  - **T4** no active space gives `null`;
  - **T5** `close()` calls `setWindowTitle(null)` once.
- **A4** `just check-syntax` and `just test-host p620` (builds the sync closure; never p510).
- **A5** `git diff --stat` shows only `freund-tabs/main.js`, `docs/applications/herdr.md`, the test script if kept,
  and the plan/spec files.
- **A6** Markdown lint on the docs file as the repo pre-push does (whole file lint).

Live, after the owner deploys p620 (the lead does not deploy); the lead may run these read-only:

- **L1** `herdr-app check` on the synced mod passes; `journalctl --user -t herdr-app-sync -n 20` shows the install.
- **L2** `hyprctl clients -j | jq -r '.[] | select(.class|test("herdr";"i")) | .title'` prints `p620: <space>`.
- **L3** Rename the space and switch spaces: repeat L2. Expected: the title follows each change.

Owner by hand (the lead must not drive the app UI):

- **O1** Press ctrl+shift+l to leave `freund`: L2 prints "Herdr". Cycle back to `freund`: the title returns.
- **O2** Quit and start the app again: the title is set once `freund` loads.
- **O3** On razer (via `just deploy-via-p620 razer`): the title shows `razer: <space>`. With a remote space, it shows
  the machine name.
- **O4** Unnamed space: in an unnamed space, `cd` to another folder in its first terminal. Expected: the title
  follows the new automatic name, checked with L2.
- **O5** No active space (if the app can reach that state): L2 prints "Herdr". Otherwise record that and rely on T4.
- **O6** The bar and alt-tab show `p620: <space>`, and "Herdr" after O1. `hyprctl` only proves the compositor got the
  title, so look at both consumers.
- **O7** Close the app and confirm no stale title in the bar or alt-tab.

After A1 to A6, L1 to L3 and O1 to O7 pass: post one short comment on upstream Issue #589
(the mod works on Linux/Wayland; a declarative `{host}: {space}` template, or a headless mod without a layout block,
would drop the need for a hosted mod). The lead
writes the comment text to a file and posts it only after the owner says so.
