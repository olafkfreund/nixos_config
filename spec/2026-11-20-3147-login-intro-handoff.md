---
status: draft
issue: 3147
intent: intent/2026-11-20-3147-login-intro-handoff.md
---

# Spec: start owed the way upstream does, with `--prepare-intro`

Per the owner's decision, the wiring comes first. The shell and IPC are
changed only if the gap stays above about 2 s after this.

## Design

### The difference

Upstream omacom/owe v0.2.17 `systemd/owed.service`:

```ini
ExecStart=/bin/bash -c 'exec %h/.local/bin/owed --prepare-intro "$("$$OMARCHY_PATH/bin/omarchy-theme-bg-boot-intro" --resolve-startup 2>/dev/null)"'
KillMode=mixed
```

olafkfreund/nixarchy `modules/home.nix:1527-1546` (main `8b5ed7c`):

```nix
ExecStart = "${owe}/bin/owed";
```

It has no `--prepare-intro` and no `KillMode`.

With `--prepare-intro <clip>`, owed decodes the clip offscreen and paused
as it starts (`main.c:1602-1610`), and logs
`login intro prepared, the shell keeps the still until it asks`. Until the
shell's boot-intro request arrives, it answers at once and leaves the still
with the shell. When the request comes, the shell lets go of its still
before the clip resumes, so the clip plays from its start under the shell's
reveal (owe README, "--prepare-intro"). If no request comes within 15 s
(`LOGIN_INTRO_WAIT_MS`), or on a lock or a renderer loss, the still goes to
the shell as usual. An empty argument keeps ordinary startup (`main.c:1527`
takes the argument, `:1605` checks `*startup_intro`).

`omarchy-theme-bg-boot-intro --resolve-startup` prints the current
background's clip, or nothing while intros (`toggles/background-intros-off`)
or animations are off. It needs `readlink`, `hyprctl` and `jq`. The unit's
`PATH` already carries all three: the omarchy package's `runtimeDeps`
includes coreutils, jq-1.8.2-bin and hyprland-0.57.0. On p620 it prints
`…/theme/backgrounds/intros/1-retro-stripes-fan.mp4`.

### Change in nixarchy (one PR)

`modules/home.nix`, the `owed` user unit:

```nix
Service = {
  ExecStart = "${pkgs.bash}/bin/bash -c 'exec ${owe}/bin/owed --prepare-intro \"$(${omarchyPath}/bin/omarchy-theme-bg-boot-intro --resolve-startup 2>/dev/null)\"'";
  # Only the daemon gets the stop signal, so it can hand the background back
  # to the shell before it stops the renderer itself (upstream owed.service).
  KillMode = "mixed";
  ...
};
```

The existing `Restart`, `RestartSec`, `Environment` (`PATH`,
`OMARCHY_PATH`) and `PartOf`/`After`/`WantedBy` stay unchanged. The
comment cites upstream's unit and this issue.

In nixarchy's `tests/options.nix`, the existing `oweService` case
(`:941-955`) asserts the **complete** generated `ExecStart` string and
`KillMode = "mixed"`. Two substring checks would pass with broken quoting.
This catches a future drift from upstream.

### Change in this repo

Move the `nixarchy` pin in `flake.lock` to the PR's merge, through the
existing flake bump for nixarchy (as in #3130 and #3137). Nothing else
changes here.

### What this fixes, and what it does not (from the Codex and agy review)

- **Fixes the lost intro.** With a prepared clip, the shell's boot-intro
  request sets `intro_release_first` (`main.c:710-711,744`). The clip stays
  paused until the shell has let go, then plays from its start. Today it
  plays to its end while owed is blocked.
- **Takes the post-intro handback (3.4 s) off the cover's path.** The
  cover can reveal on the moving intro (`BackgroundIntro.qml:114-118`)
  instead of waiting for `intro_finish()` → `switch_to_shell()`.
- **Does not remove the 6.7 s shell IPC block.** In
  `owed_app_poll_intro()`, `intro_release_first` still calls
  `activate_renderer()` → `owed_shell_plugin_set(false)` (`main.c:848-860`,
  `:273`) before it sends `intro-start`, and the cover waits for that.

Expected result: the cover lifts at about +9.8 s instead of +14.2 s, still
above the 2 s target. Per owner decision 1, that block is the next change
(verification step 6), not part of this one.

## Alternatives rejected

- **Patch owe so it never blocks on a starting shell, in the same round.**
  The owner chose wiring first. This is the likely next step, because the
  block remains on the prepared path.
- **Patch the shell's login cover so it reveals without its background.**
  Same reason. The cover's logic is upstream's design for the prepared
  path.
- **Disable the intro.** Ruled out by the owner.
- **Override the unit in this repo** with `systemd.user.services.owed` in
  home-manager. That would fix p620 and razer but not nixarchy itself, and
  the bug is nixarchy's.

## Risks

- **The resolver at unit start.** It reads `hyprctl` for the animations
  setting. If Hyprland's socket isn't up yet, `hyprctl` fails, the
  animations check reads "on", and the clip is still resolved, which is
  harmless. If the resolver fails outright, the argument is empty and owed
  starts as it does today.
- **Prepared but never requested:** after 15 s owed hands the still to the
  shell. At worst this is today's behaviour, never a stuck black screen.
- **`KillMode=mixed`:** on stop, only owed gets SIGTERM, and `owe-render`
  is stopped by owed after the handback. This matches upstream. A hung
  renderer is still killed at the end of `TimeoutStopSec`.
- **`prepare_intro()` runs before owed enters its event loop**
  (`main.c:1592-1620`). On a slow renderer start (up to 7 s), the shell's
  boot-intro helper gives up after 5 s of `owe status` polling, and that
  login simply has no intro. On p620 the renderer starts in 150 ms.
- **A second start of owed mid-session** (after a crash, or by hand)
  prepares the intro again and holds the still with the shell for up to
  15 s. This matches upstream.
- **Hosts:** p620 and razer, through the nixarchy pin. p510 runs nixarchy
  too and gets it only with the owner's OK.

## Verification

1. **In nixarchy, eval-time:** the new unit assertion passes, and the
   existing checks pass.
2. **In nixarchy, VM smoke test only:** `checks.coexist` still passes:
   the session boots and paints. It is not a timing measure. Its 5 s
   sampling, its 9-16 attempt spread on unchanged code, and its comparison
   with the final still's colour make it unfit for a before/after.
3. **On p620, after the pin bump and a fresh login, with the probe:**
   - owed logs `login intro prepared`, and no
     `shell not up yet, the still waits for it`;
   - record the gap from both `omarchy-bar` mapped to the cover closed.
     Expected about 7 s, against 11.3 s today, and still above the 2 s
     target;
   - the intro is seen: owed's `intro playing` → `intro fading to still`
     span is the clip's length, not today's 1 ms. A probe screenshot inside
     it, if one lands there, is neither black nor the final still;
   - `systemctl --user cat owed` shows the new `ExecStart` and
     `KillMode=mixed`, and one stop and start of the unit leaves the
     wallpaper on screen with no stray `owe-render`.
4. **On razer:** the same checks, with a temporary copy of the probe for
   one login. Remove it afterwards.
5. **Theme switch on p620:** switch to a theme with an intro and back. The
   switch ends on the correct still with no visible gap, as today.
6. If the gap in step 3 is still above about 2 s, record the new timeline
   on #3147 and propose the next change (shell IPC at login, or the
   cover's reveal) as a new spec revision for the owner.
