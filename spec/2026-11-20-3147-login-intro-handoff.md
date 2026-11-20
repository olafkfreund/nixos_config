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

A test in nixarchy's eval-time checks asserts that the generated unit's
`ExecStart` contains `--prepare-intro` and `--resolve-startup`, and that
`KillMode` is `mixed`. The file is `tests/options.nix` or wherever the
`owed` unit is already checked, and the plan names it. This catches a
future drift from upstream.

### Change in this repo

Move the `nixarchy` pin in `flake.lock` to the PR's merge, through the
existing flake bump for nixarchy (as in #3130 and #3137). Nothing else
changes here.

## Alternatives rejected

- **Patch owe so it never blocks on a starting shell.** That is a source
  change upstream, while upstream's own wiring already avoids the blocking
  path. It comes back only if the measured gap stays above about 2 s.
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
- **Hosts:** p620 and razer, through the nixarchy pin. p510 runs nixarchy
  too and gets it only with the owner's OK.

## Verification

1. **In nixarchy, eval-time:** the new unit assertion passes, and the
   existing checks pass.
2. **In nixarchy, VM before and after:** run `checks.coexist`
   (`tests/coexist.nix`) on main and on the PR branch, and compare the
   attempt on which the desktop first matches its wallpaper. On CI today
   that is attempts 9-16 of 24 at 5 s each, "first paint waits for owed's
   shell enable/disable cycle" (#1537). A lower attempt number on the
   branch is evidence that does not depend on p620's hardware. A VM has no
   GPU, so its absolute times are not comparable with p620's, only the
   difference between main and the branch.
3. **On p620, after the pin bump and a fresh login, with the probe:**
   - owed logs `login intro prepared`, and no
     `shell not up yet, the still waits for it`;
   - the cover closes within about 2 s of both `omarchy-bar` mapping,
     against 11.3 s today;
   - the intro is seen: at least one probe screenshot during the playback
     window is neither black nor the final still. If the clip is too short
     to catch at the 2.4 s sampling, the owed journal's `intro playing` →
     `intro finished` span shows a real playback length instead of today's
     1 ms.
4. **On razer:** the same checks, with a temporary copy of the probe for
   one login. Remove it afterwards.
5. **Theme switch on p620:** switch to a theme with an intro and back. The
   switch ends on the correct still with no visible gap, as today.
6. If the gap in step 3 is still above about 2 s, record the new timeline
   on #3147 and propose the next change (shell IPC at login, or the
   cover's reveal) as a new spec revision for the owner.
