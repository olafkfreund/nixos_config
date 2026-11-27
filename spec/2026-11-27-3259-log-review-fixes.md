---
status: approved
issue: 3259
intent: intent/2026-11-27-3259-log-review-fixes.md
---

# Spec: Fix problems from the 2026-11-27 fleet log review

## Design

Four code changes, two in this repo per host, one in `factory-gitops`. The
rest are done or closed without code.

### A. razer: Wi-Fi and audio power saving off (items 4, 5)

`hosts/razer/nixos/laptop.nix:56` already holds razer's
`boot.extraModprobeConfig` (i915 options). Add three lines there:

```text
options iwlwifi power_save=0
options iwlmvm power_scheme=1
options snd_hda_intel power_save=0
```

- `NMI_INTERRUPT_LMAC_FATAL` on the AX210 (`ty-a0-gf-a0`, firmware 89) is
  commonly triggered by power-save transitions; `power_scheme=1` is "active"
  (no power save) in iwlmvm, `power_save=0` turns off the iwlwifi side.
- `stream N dma error` from `snd_hda_intel` on Intel HDA follows the
  controller's runtime power-down; `power_save=0` keeps the codec up.
- Cost: slightly higher idle draw on battery. Both are module options, so a
  bad result is a one-line revert.

### B. razer: `/boot` mounted private (item 6)

`hosts/razer/nixos/hardware-configuration.nix:27`: `fmask=0022` /
`dmask=0022` → `fmask=0077` / `dmask=0077`, the NixOS installer's current
default. Takes effect on remount or reboot; the plan remounts in place.

### C. p620: schedule watchdog survives rate limits (item 7)

`hosts/p620/nixos/schedule-watchdog.nix`:

- In the `run` wrapper, before `exec`, read the remaining core quota with
  `gh api rate_limit --jq .resources.core.remaining` (that endpoint does not
  count against the quota). Below 500, print one line and `exit 0`, so a
  drained token skips a tick instead of failing the unit.
- Timer `OnCalendar = "*:0/5"` → `"*:0/15"`: a third of the API calls. The
  watchdog starts runs GitHub's scheduler missed by far more than 15 minutes,
  so the finer grain bought nothing.

### D. factory-gitops: OpenObserve memory (item 3)

`apps/observe/manifests/manifests.yaml:171` (origin/main): limit `2Gi` →
`4Gi`, request `512Mi` → `1Gi`, with the comment updated (977Mi in use on
2026-11-27, 8 OOM restarts at 2Gi). Separate branch and PR in that repo; the
cluster picks it up from GitOps.

### Done or closed without code

- Item 1 (p510 `/dev/sdd`): long SMART self-test started 2026-11-27 12:31,
  finishes about 06:30 on 28 Nov. Result goes on the issue. Replacement is a
  hardware job for the owner.
- Item 2 (Hyprland SIGSEGV): not the session. The core dump's command line is
  `Hyprland --verify-config` from a herdr review scope, the known upstream bug
  hyprwm/Hyprland#16591 (timers in a Lua config crash the validator on
  exit). Upstream no longer accepts issues; nothing to file. Noted on the
  issue.
- Item 7 one-offs: `nixi-whatsapp` hit its start limit on 26 Nov and has run
  since; `morning-repo` has run cleanly since; `omarchy-voice` timed out
  stopping once. No change; they are watched, not fixed.
- `/home`: Steam library and caches deleted on the owner's word (83% → 46%).

## Alternatives rejected

- iwlwifi `11n_disable` / disabling Wi-Fi 6E: costs throughput and targets
  a different failure.
- Pinning older iwlwifi firmware: we cannot pick one firmware file without
  overriding `linux-firmware`, which is far more than a module option.
- Watchdog fix in nixarchy's script: owner chose this repo, and the failure
  is in how p620 drives the script (token, cadence), not its decisions.
- Moving the watchdog to its own GitHub token: needs a new secret; the
  precheck and slower cadence fix the failure without it.
- Higher OpenObserve limit than 4Gi: 977Mi in use, so 4Gi gives four times
  the headroom; p620 has 251 GB, but a cap still protects the node.

## Risks

- razer battery life drops a little with power saving off. Revert is one
  line.
- If the module options do not stop the firmware crash, the cause is the
  firmware; the next step would be a newer `linux-firmware`.
- Remounting razer `/boot` with new masks while nothing writes there is
  safe; if the remount fails, the reboot applies it.
- The watchdog reacts up to 15 minutes later than before.
- OpenObserve can use up to 4Gi on p620.

## Verification

- `just test-host razer` and `just test-host p620` build.
- razer, after deploy: `cat /sys/module/iwlmvm/parameters/power_scheme` is 1,
  `cat /sys/module/snd_hda_intel/parameters/power_save` is 0 (after a module
  reload or reboot), `findmnt /boot -o OPTIONS` shows `fmask=0077`, and
  `bootctl status` no longer warns. Over the next day `journalctl -k -g
  'NMI_INTERRUPT|dma error'` is empty or far below today's counts.
- p620: `systemctl --user list-timers nixarchy-schedule-watchdog` shows a
  15-minute cadence; the unit stays inactive (not failed) across ticks.
- k3d: `observe` pod limits show 4Gi and the restart count stops rising.
