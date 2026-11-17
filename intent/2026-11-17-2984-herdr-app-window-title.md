---
status: draft
issue: 2984
author: olafkfreund
---

# Intent: herdr-app window title with host and workspace

## Problem

The Herdr TUI sets the terminal window title to `{hostname}: {workspace}`
(`home/development/herdr.nix` lines 152-155, `window_title`). Hyprland's bar and
alt-tab read that title, so on a TUI session you can tell hosts and
workspaces apart.

The desktop app (`herdr-app`) shows only "Herdr". The gap is listed in
`docs/applications/herdr.md` (known-gaps table, line 397) and was accepted
in the approved spec of Issue #2978. With several Herdr windows or hosts
open, the bar and alt-tab entries are indistinguishable.

Issue #2984 says herdr-app has no title setting and suggests asking upstream.
That is out of date. Upstream already shipped the API:

- Upstream issue `herdrdev/herdr-app` #589, "Configurable window title (e.g. include the current Space)":
  <https://github.com/herdrdev/herdr-app/issues/589>. It is still open.
- Upstream PR #681, "feat: let mods set the window title", merged 2026-11-12:
  <https://github.com/herdrdev/herdr-app/pull/681>. It adds `setWindowTitle(title)` to the mod API.
- That commit is contained in tag `v0.1.16` (52 commits behind it). The `defaults/herdr.d.ts` at that tag
  documents it: last call wins across mods, `null` restores "Herdr", it does not survive an app restart, and it
  should be called when the title changes, not on every render.
- `pkgs/herdr-app/default.nix` line 27 already pins `version = "0.1.16"`, so the host has the API.

There is still no declarative `window_title` setting like the TUI's. Issue #589 proposes one
(`{ "window_title": "{space} - {tab} - {title}" }`) but it is not implemented. So the answer is a mod, not a setting.

## Proposed outcome

Verdict: do it, with a small local mod. No upstream filing is needed for the core goal.

- A managed mod calls `setWindowTitle` with `<host>: <active space name>`. This mirrors the TUI's format and the
  example in PR #681. Whether it is a new mod or a change to an existing one (`freund-tabs`) is left to the spec.
- The title is refreshed whenever the resulting string changes: the active space changes, the active space is
  renamed, or its automatic name changes (upstream derives unnamed space names from the first terminal's current
  location, `defaults/herdr.d.ts` at `v0.1.16`, not checked locally).
- Hyprland and the bar show that title for the app window on p620 and razer.
- `herdr-app-sync` ships the mod like the other managed mods. Upstream says a mod only runs while a layout block
  hosts it. PR #681 itself calls a 1px block "a little janky" and asks for a better home.
- `docs/applications/herdr.md` drops the gap row for Issue #2984 and documents the behaviour.

Not chosen:

- A Hyprland rule. `windowrule` and `renamewindow` set a fixed title or match on one. They cannot follow the active
  space, so they cannot do this.
- Waiting for a `window_title` setting upstream. It would be tidier, but Issue #589 is still open with no
  implementation known to us (not checked for a milestone), and the API needed exists now.

Optional upstream follow-up (not a blocker): comment on #589 that a declarative `{host}: {space}` template, or a
way to run a headless mod without a layout block, would remove the 1px block. Only file it if the owner wants.

## Affected users and systems

- The owner, on p620 and razer (the hosts that run herdr-app; Issue #2861). p510 is not touched and nothing is
  built or deployed there.
- Depending on the spec's choice: `home/development/herdr-app/mods/freund-tabs/main.js` alone (already placed in
  `layouts/freund.json` line 84 and already reading the active space at line 92), or a new mod directory plus
  `home/development/herdr-app.nix` (the `ours` list at about line 54) and one block in `layouts/freund.json`.
- `docs/applications/herdr.md` (gap table and the managed-items list). The Backstage `mkdocs.yml` nav does not
  change unless a new page is added.
- Pane titles inside the app are separate and unchanged (upstream Issue #1154 covers mod pane titles).

## Constraints

- The hostname must come from the mod. `exec("hostname", ["-s"])` is what PR #681 uses. The TUI renders it on the
  herdr server. `SpaceInfo.machine` is the machine name from `hc machine ls` (per `defaults/herdr.d.ts`, not checked
  locally), and upstream does not promise it equals the remote short hostname.
- Upstream title changes are explicit requests with no ownership (`src/window.rs` at `v0.1.16`, not checked
  locally). So a title set under `freund` stays when the layout changes, unless the mod resets it.
- `herdr-app-sync` only installs a mod after `herdr-app check` passes, and the app owns `~/.config/herdr-app`,
  so the mod ships through the sync, not as a store symlink.
- A mod with `"place": "none"` (like `notify`) is not drawn. Whether it keeps running without a layout block must
  be confirmed on the real app. Upstream's wording says it does not.
- Call `setWindowTitle` only when the title changes (upstream rule), and again on mod start, since the title
  does not persist.
- Keep it small: no settings, no templating language.
- Home Manager is a flake module, never `home-manager switch`. Test with `just test-host p620`. Agents do not
  deploy, restart or commit.

## Open questions

1. Is the issue's premise wrong? Recommendation: yes. Treat it as "build a mod on `setWindowTitle`", and say so in
   the PR and close the premise in the issue comment. Do not file upstream first.
2. Where does the mod run? Options: a 1px block in the sidebar of `freund.json`, or an existing mod
   (`freund-tabs` already reads `spaces()` at `main.js` line 92) that also calls `setWindowTitle`.
   Recommendation: add the call to `freund-tabs`, since it is already placed and already tracks the active
   space. This avoids a new block and a new mod. If that mixes concerns too much, use a separate 1px block.
   The spec decides; this intent does not.
3. Title for a remote space? Two different requirements: the configured machine name (`SpaceInfo.machine`) or the
   actual remote short hostname (what the TUI shows). Recommendation: use `machine` when set, else local
   `hostname -s`, and say in the docs that it is the machine name. The owner picks.
4. Layouts. `ctrl+shift+l` cycles layouts (`docs/applications/herdr.md` line 376) and the title is not tied to
   `freund`. Must titles work in every layout, or should leaving `freund` restore "Herdr"? Verification must
   include switching away from `freund` and back.
5. Title when no space is active or the mod unloads? Recommendation: `null`, which restores "Herdr".
6. Does `herdr-app` 0.1.16 on Linux/Wayland pass the title to Hyprland? PR #681 was tested only on macOS. The
   owner should confirm with `hyprctl clients` after a test build. If the title does not reach Hyprland, that is a
   upstream bug to file, and the verdict becomes "upstream-first".
7. Is a comment on upstream #589 wanted? Recommendation: yes, one short comment after the mod works, with
   the 1px-block finding. Low priority and the owner's call.
