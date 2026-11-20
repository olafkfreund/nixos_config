---
status: draft
issue: 3147
author: olafkfreund
---

# Intent: show the desktop at login without waiting on the wallpaper-intro handoff

Follow-up to #3118 (login feels slow) and #3139 (herdr menu unloads).

## Problem

On p620 the screen stays black for about 11 s after login, although the
Omarchy shell and both bars are up about 3 s in. The startup probe
(`~/.local/state/startup-probe/1795185318.log`, with screenshots) measured
the 2026-11-20 14:35 login. Times are from the probe start:

| t | Event (source) |
|---|---|
| +2.9 s | shell background and both bars mapped; the shell's login cover starts |
| +3.0 s | owed logs `intro preparing …/intros/1-retro-stripes-fan.mp4`; `owe-render` maps an opaque `owe-background` |
| +3.0 → +9.7 s | owed asks the starting shell to suspend its background (`src/daemon/shell.c`: `omarchy-shell background setSuspended true`, 5 s timeout, then a `setPluginEnabled` fallback). It succeeds at +9.7 s (`shell background disabled`) |
| +9.7 → +10.8 s | the intro plays and fades straight to the still (`intro finished`) |
| +10.8 → +14.2 s | owed keeps the background on purpose for a "startup window" (`intro_finish`, `src/daemon/main.c:530-534`), then logs `shell background enabled` |
| +14.2 s | the shell background is back. The login cover (`shell/services/BackgroundIntro.qml`) reveals only when the shell's own background is active and ready (`backgroundReady`), or after its 10 s fallback |
| +14.8 s | the first screenshot with wallpaper and bars. Every earlier one is black |

So the shell's login cover waits for the shell's background, which owe has
suspended for the intro. owe waits on a shell that is still starting to
accept the suspend, and then holds the background on purpose after the
intro. The result is about 11 s of black screen, even though the desktop
behind it is ready.

Contributing load: at login, `.desktop` entries and `mimeinfo.cache` are
rebuilt five times in the first 8 s (hyprchroma, `omarchy-agent-*.desktop`).

## Proposed outcome

- After login, the desktop (wallpaper and bars) is visible within about
  1 s of the shell being up, measured by the same probe, instead of about
  11 s later.
- The theme's login intro is kept. It plays where it can, and it never
  holds the desktop hidden.
- This holds on every nixarchy host with a theme intro: p620 and razer,
  and p510 once the owner allows a deploy there.
- The fix lives where the behaviour lives: owe (omacom/owe) and/or the
  Omarchy shell (omacom/omarchy). It is carried in nixarchy
  (olafkfreund/nixarchy) as a numbered patch, its existing pattern, until
  upstream has it. This repo only moves its nixarchy pin.

## Affected users and systems

- Hosts: p620, razer and p510. All three run the Omarchy desktop via
  nixarchy, and owe is on wherever `programs.nixarchy.owe.enable` is set.
- Repos:
  - olafkfreund/nixarchy: `pkgs/apps/owe.nix`, `pkgs/omarchy/default.nix`
    and its patches;
  - upstream omacom/owe and omacom/omarchy;
  - this repo's `flake.nix` nixarchy pin.
- The startup probe (a temporary user unit from #3118) is the measuring
  tool, and it runs on p620 only.

## Constraints

- Do not disable the intro to get the speed. The owner asked for a real
  fix.
- Upstream PRs to omacom repos are public and outside the owner's control.
  Draft them, and file one only with the owner's OK.
- Keep nixarchy's patch discipline: numbered patches applied with
  `--fuzz=0`, which fail the build when upstream moves.
- p510 needs the owner's OK before any build or deploy. Bus announcements
  before switching p620 or razer.
- Theme switches use the same owe/shell intro handoff
  (`BackgroundSwitch.qml`), and they must not get worse.

## Open questions

1. **Where to fix first.** The candidates are:
   - the shell's login cover, which could reveal on the bars and
     whichever background is showing instead of waiting for its own
     background;
   - owe, which could skip the post-intro hold at login and stop blocking
     on a starting shell;
   - both.

   The spec will pick the smallest change that meets the outcome and
   doesn't affect theme switches.
2. **Upstream.** Should the fix also be offered upstream (omacom/owe,
   omacom/omarchy) once it is proven in nixarchy, or kept as a nixarchy
   patch only?
3. **The login rebuild churn** (`.desktop` and `mimeinfo.cache`): fix it in
   this task, or in a separate issue? It is load, not the cause.
