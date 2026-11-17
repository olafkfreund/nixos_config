---
status: approved
issue: 2986
author: olafkfreund
---

# Intent: herdr-app: lazygit as a floating terminal

## Problem

The Herdr TUI opens lazygit in a 90% popup: `[[keys.command]] type = "popup"` with `width = "90%"`
(`home/development/herdr.nix:236-242`). The Herdr desktop app on p620 and razer cannot do this yet.
`ctrl-shift-g` runs `terminal.open` with `place = "tab"` (`home/development/herdr-app.nix:46`), so lazygit
takes a whole tab, so the surrounding terminal context is out of sight while lazygit runs. The tab closes
when lazygit exits (`docs/applications/herdr.md:371`). The app's `terminal.open` accepts only `tab`, `right`
and `down` as places. The approved spec for Issue #2978 accepted this as a gap
(`spec/2026-11-16-2978-herdr-app-parity.md:313,443`), and `docs/applications/herdr.md:399` lists it.

Upstream state, checked 2026-11-17 on `herdrdev/herdr-app`:

- Issue 677, "Mod API: no way to open a floating terminal running a shell command", is open with no comments
  and no maintainer reply. <https://github.com/herdrdev/herdr-app/issues/677>
- Issue 781 says a mod can already show a terminal in a `window` overlay (started with `hc run --bg`), but no
  command gives that terminal the keyboard. Only a mouse click does. It is open. A commenter reports the same
  problem with lazygit and offers a fix. <https://github.com/herdrdev/herdr-app/issues/781>
- Pull request 388, "pane.focus reaches a terminal block in a window", is open. It fixes targeting the
  overlay terminal only. <https://github.com/herdrdev/herdr-app/pull/388>
- Pull requests 877 ("preserve keyboard focus in terminal popups") and 995 ("target floating terminals and
  restore their focus") are open. They cover the wider focus lifecycle, which issue 781 also needs.
  <https://github.com/herdrdev/herdr-app/pull/877>, <https://github.com/herdrdev/herdr-app/pull/995>
- Versions: this repo pins herdr-app 0.1.16 (`pkgs/herdr-app/default.nix:27`); the executable installed here
  reports 0.1.15; issue 781 was first reported on 0.1.14 on macOS. Upstream `pane.focus` searches visible
  layout terminal blocks and model panes, not overlay windows. Behaviour in the pinned Linux binary is
  read from source and reports, not tested.

## Proposed outcome

Honest answer: still parked, wait for upstream. With the documented mod API, an in-app
overlay cannot be given the keyboard by a command today, so nothing keyboard-only can be built inside the app.

- Do not change code for this issue now. Keep `ctrl-shift-g` as a tab.
- Re-check when issue 677 or 781 closes and pull requests 388, 877 and 995 have shipped in a release,
  or when a herdr-app release changes the `terminal.open` places.
  The bump recipe in `pkgs/herdr-app/default.nix` is the natural moment.
- When upstream lands, the change is small: `ctrl-shift-g` uses the new float place, or a small mod opens the
  overlay window with focus. The docs row at `docs/applications/herdr.md:371,399` is then corrected.

## Affected users and systems

The owner, on p620 and razer, who run the herdr-app desktop app. The Herdr TUI is unchanged and keeps its
popup. p510 is not involved.

## Constraints

- No fork or patch of the prebuilt herdr-app binary (`pkgs/herdr-app/default.nix`, fetched from
  `releases.herdr.dev`).
- Mods live in `home/development/herdr-app/mods/`, listed in `ours` in `home/development/herdr-app.nix`, and
  must pass `herdr-app check` in `herdr-app-sync`.
- If anything is built later, it must not need a mouse click, and it must keep the lazygit tab as the
  fallback.
- No build or deploy on p510. Deploy on p620 and razer follows the repo's usual rules.

## Open questions

1. Is a tab acceptable until upstream ships? Recommendation: yes. It works, it closes when lazygit exits, and
   the cost is only a tab switch.
2. Build a mod now using a `window` overlay plus `hc run --bg` (the shape in issue 781)? Recommendation: no.
   Without a way to focus the overlay's terminal, the first keystrokes go to the pane behind it, so the
   popup is not usable from the keyboard.
3. Use a Hyprland floating window running lazygit through `hc run` and `hc attach` instead?
   Recommendation: no. It would work today, but it leaves the app's window, needs a terminal and window rule
   outside herdr-app, and bypasses the app's workspace and tab model. Revisit only if the owner prefers a float
   over staying inside the app.
4. Should we comment on issue 677 or 781 with our use case? Recommendation: yes, one short comment on issue
   677 saying the Herdr TUI has this today and lazygit is the main case. The owner should decide, since it is
   a public post.
5. What focus lifecycle must work before we build? Recommendation: all three. Keys go to lazygit on open. A
   palette or menu opened over lazygit returns focus to it on close. Focus returns to the original terminal
   when lazygit exits. Initial focus alone is not enough, so closing issue 781 is not the trigger; a released
   build that passes all three is.

## Decision

Approved by the owner on 2026-11-17, with the recommendation given for each open question above.
