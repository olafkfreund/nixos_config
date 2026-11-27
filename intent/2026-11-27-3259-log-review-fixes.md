---
status: draft
issue: 3259
author: olafkfreund
---

# Intent: Fix problems from the 2026-11-27 fleet log review

## Problem

A log sweep of p620, razer and p510 on 2026-11-27 found no failed units, but
seven real problems:

1. **p510 media disk is failing.** `/dev/sdd` (Seagate ST12000NM0127, 12 TB,
   `/mnt/media`, 16.8k hours): 3288 reallocated sectors, 544 pending (536 on
   25 Nov), 1893 reported uncorrectable, and live `READ FPDMA QUEUED … UNC`
   errors. smartd logs it about 150 times a day.
2. **Hyprland crashes on exit on p620.** SIGSEGV on 26 Nov in
   `Config::Lua::CConfigManager::cleanTimers` → `CEventLoopManager::removeTimer`
   during the config manager's destructor (Hyprland 0.57.0, commit 64bde62).
3. **OpenObserve keeps getting OOM-killed.** The `observe` deployment in the
   k3d `factory` cluster on p620 has a 2Gi memory limit and has restarted 8
   times (last `OOMKilled` 27 Nov 11:19). Its manifest lives in the
   `factory-gitops` repo (`apps/observe/manifests/manifests.yaml`), not here.
4. **razer Wi-Fi firmware crashes.** `iwlwifi … NMI_INTERRUPT_LMAC_FATAL`
   (firmware 89, `ty-a0-gf-a0`) five times in one boot, each a Wi-Fi drop.
5. **razer audio DMA errors.** `snd_hda_intel 0000:00:1f.3: stream 7 dma
   error: 0x28` about 600 times this boot, still ongoing.
6. **razer `/boot` is world-readable.** It is mounted `fmask=0022,dmask=0022`
   (`hosts/razer/nixos/hardware-configuration.nix:27`), so bootctl warns that
   the random seed file is a security hole.
7. **p620 user services fail.** `nixarchy-schedule-watchdog`
   (`hosts/p620/nixos/schedule-watchdog.nix`) runs every 5 minutes and fails
   when the GitHub API rate limit for the shared token is exhausted, which it
   helps exhaust. One-off failures: `nixi-whatsapp` (start-limit-hit 26 Nov,
   running now), `omarchy-voice` stop timeout, `morning-repo` routine (ran
   fine since).

Separately, p620 `/home` is 83% full (730 of 938 GB) and the owner wants to know
what uses it.

## Proposed outcome

- 1: the data on `/mnt/media` that cannot be re-downloaded is safe and a
  replacement is planned. Hardware cannot be fixed in config.
- 2: an upstream report exists with the backtrace, if the crash is not
  already known and fixed upstream.
- 3: `observe` stops being OOM-killed (higher limit in `factory-gitops`).
- 4, 5: after a razer deploy, the iwlwifi firmware crashes and HDA DMA errors
  stop or drop sharply over a normal day.
- 6: razer `/boot` is mounted `0077` and bootctl stops warning.
- 7: the watchdog no longer fails the unit when GitHub rate-limits it, and
  uses fewer API calls; the one-off failures are explained or fixed.
- A `/home` usage report with the large reclaimable items. Nothing deleted
  without the owner's OK.

## Affected users and systems

- razer: kernel module options, `/boot` mount (items 4–6). Needs a deploy via
  `just deploy-via-p620 razer`; `/boot` mask changes need a remount or reboot.
- p620: the schedule-watchdog module (item 7), the k3d `factory` cluster
  (item 3, other repo).
- p510: hardware only (item 1). No build or deploy there.
- Upstream: hyprwm/Hyprland (item 2), possibly olafkfreund/nixarchy (the
  watchdog script lives at `.github/scripts/schedule-watchdog.sh` there).

## Constraints

- p510: no build or deploy without the owner's OK. A long SMART self-test on a
  failing disk adds load; ask first.
- Filing an upstream issue is public; confirm the text first.
- Announce on the agent bus before any deploy or restart.
- Must not lose Wi-Fi or audio on razer: options are standard, revert is one
  line.
- No deletion under `/home` in this task; report only.

## Open questions

- Item 1: run a long SMART self-test on p510 `/dev/sdd` now, or only back up?
- Item 2: OK to file the Hyprland issue upstream (after checking it is not
  already reported)?
- Item 3: change `factory-gitops` in this task (separate PR there), or leave a
  note for that repo?
- Item 7: fix the watchdog here (treat rate-limit as skip, slow the timer) or
  in the nixarchy script?
