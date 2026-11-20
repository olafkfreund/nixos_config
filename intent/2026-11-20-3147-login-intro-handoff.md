---
status: approved
issue: 3147
author: olafkfreund
---

# Intent: show the desktop at login without waiting on the wallpaper-intro handoff

Follow-up to #3118 (login feels slow) and #3139 (herdr menu unloads).

## Problem

On p620 the screen stays black for about 11 s after login, although the
Omarchy shell and both bars are up about 3 s in. The startup probe
(`~/.local/state/startup-probe/1795185318.log`) and the owed journal
measured the 2026-11-20 14:35 login. Times are from the probe start.

| t | Event (source) |
|---|---|
| +2.9 s | Both bars map (layer 2). The shell's **login cover** maps above them on both outputs: `omarchy-background` at layer 3 (Overlay), a full-screen black surface (`BackgroundIntro.qml:291-314`) |
| +3.0 s | owed logs `intro preparing …/intros/1-retro-stripes-fan.mp4` and starts the clip offscreen at once. It then asks the still-starting shell to suspend its background (`shell.c:44-62`: `omarchy-shell background setSuspended true` with a 4 s IPC timeout inside a 5 s spawn, then a `setPluginEnabled` fallback) |
| +9.7 s | That IPC returns (`shell background disabled`), 6.7 s later. By then the clip has reached its end. `intro playing` and `intro fading to still` are logged 1 ms apart, so the intro is never seen, and the shell's reveal-on-moving-video path (`BackgroundIntro.qml:114-118`, `framePoll`) has nothing to catch |
| +10.8 s | `intro finished`. `intro_finish()` re-enables the shell background at once (`main.c:530-534` → `switch_to_shell()`), with no deliberate hold |
| +14.2 s | That IPC returns (`shell background enabled`), 3.4 s later. The shell's background maps (layer 0) and the login cover closes. The cover lifts on a ready shell background (`backgroundReady`), or after its own 10 s fallback |

What keeps the screen black is the shell's login cover, and it stays up
for two reasons:

1. **nixarchy starts owed differently from upstream.** Upstream's unit
   (`omacom/owe` `systemd/owed.service:9`) runs
   `owed --prepare-intro "$(omarchy-theme-bg-boot-intro --resolve-startup)"`.
   With that flag, owed "answers at once and leaves the still with the
   shell". The clip plays from its start only once the shell asks and is
   free to reveal it (owe README, `main.c:1602-1610`). nixarchy's `owed`
   user unit (`modules/home.nix`) runs plain `owed`. So at login owe starts
   the clip early and blocks on the shell, and the intro is lost.
2. **Each owe → shell IPC takes 3.4-6.7 s while the shell is starting.**
   The same call takes 0.13 s once the shell is up.

Contributing load, not the cause: in the first 8 s the probe records three
`omarchy-agent-*.desktop` writes and three `mimeinfo.cache` rebuilds.

## Proposed outcome

- At login the cover closes within about 2 s of both bars mapping. The
  probe measures this from its layer events, both `omarchy-bar` mapped →
  the layer-3 `omarchy-background` closed, and a screenshot after the
  close confirms wallpaper and bars. Today the gap is 11.3 s.
- The intro is kept and actually seen. It plays from its start under the
  shell's reveal, as upstream designed, or it is skipped for that login if
  it isn't ready in time. It never holds the desktop hidden. The existing
  intro and animation toggles and the once-per-session rule are unchanged.
- Theme switches, which use the same handoff (`BackgroundSwitch.qml`),
  still end on the correct still with no visible gap.
- This holds on p620 and razer, each verified with the probe after a
  login. On p510, only with the owner's OK.

## Affected users and systems

- Hosts: p620, razer and p510 run the Omarchy desktop via nixarchy, and
  owe runs wherever `programs.nixarchy.owe.enable` is set.
- Repos:
  - **olafkfreund/nixarchy:** the `owed` user unit in `modules/home.nix`
    and `pkgs/apps/owe.nix`. Shell patches in `pkgs/omarchy/` only if still
    needed.
  - **This repo:** the nixarchy pin in `flake.nix`.
  - **Upstream omacom/owe and omacom/omarchy:** only if a source change
    turns out to be needed.
- The startup probe: a temporary user unit from #3118, today on p620 only.
  It needs a copy on razer to verify there.

## Constraints

- Don't disable the intro to get the speed. The owner asked for a real
  fix.
- Prefer matching upstream's wiring over patching sources. Any source patch
  in nixarchy follows its numbered `--fuzz=0` pattern.
- Upstream PRs to omacom repos are public and outside the owner's control.
  Draft them, and file one only with the owner's OK.
- p510 needs the owner's OK before any build or deploy. Post a bus
  announcement before switching p620 or razer.
- The probe remains temporary and stays out of the repo. #3118 removes it
  when it is settled.

## Decisions (owner, 2026-11-20)

1. **Wiring first.** Match upstream's `--prepare-intro` wiring in nixarchy,
   then measure. Change the shell or IPC only if the gap stays above about
   2 s.
2. **A late intro is skipped.** If the intro isn't ready in time, the cover
   lifts onto the still and that login has no intro.
3. **The probe goes on razer** temporarily for one verification login.
4. **The login churn is a separate issue.**
