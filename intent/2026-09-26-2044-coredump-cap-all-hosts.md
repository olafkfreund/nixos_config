---
status: approved
issue: 2044
author: olafkfreund
---

# Intent: every host caps its coredump storage

## Problem

Issue #1448 capped coredump storage at `MaxUse = "1G"`, `KeepFree = "10G"`
in `modules/system/logging.nix`. The cap only takes effect when
`system.logging.enableFiltering` is on, and only p620 turns it on.

| Host | Imports `logging.nix` | `enableFiltering` | Live `[Coredump]` | Root |
| --- | --- | --- | --- | --- |
| p620 | yes | yes | `MaxUse=1G`, `KeepFree=10G` | 916G |
| p510 | yes (`hosts/p510/nixos/resilience.nix`) | no | empty | 226G, 55G free |
| razer | no | no | empty | 938G |

With no setting, systemd lets coredumps grow to 10% of the filesystem before
it evicts any. That is about 22G on p510 and about 94G on razer. The
nixpkgs tmpfiles rule removes cores after two weeks, but a crash loop fills
the disk well inside two weeks. p510 has the least headroom and is a
headless media server, which is the worst place to find a full disk.

A sweep on 2026-09-26 found p620 sitting exactly at its 1G cap, so the cap
works where it is set. razer and p510 held no cores that day, so nothing is
on fire. The gap is latent.

The repeat crashers behind p620's 1G are all upstream and already tracked,
so this task doesn't cover them:

- quickshell 0.3.1 `IpcHandler::updateRegistration`: quickshell-mirror/quickshell#1171
- aquamarine `flushAsyncCommitEvents` on exit with more than one output:
  hyprwm/aquamarine#383
- qemu virgl in radeonsi, from manual `egl-headless` runs in `/mnt/data/vmtest`

## Proposed outcome

- On all three hosts, `systemd-analyze cat-config systemd/coredump.conf`
  shows `MaxUse=1G` and `KeepFree=10G`.
- The cap no longer depends on the unrelated journald noise-filtering switch,
  so a new host gets it without anyone remembering to.

## Affected users and systems

- Hosts: p620 (no behaviour change), razer and p510 (they gain the cap).
- `modules/system/logging.nix`, and wherever the cap ends up living.
- Deploys: razer through `just deploy-via-p620 razer`, and p510 **only with
  your explicit go-ahead**.

## Constraints

- p510 is never built or deployed without asking.
- razer and p510 must not pick up the journald filtering as a side effect:
  `MaxLevelStore=info`, rate limits, 7-day retention. That would change what
  their logs keep.
- Keep the #1448 numbers (1G / 10G). It was a deliberate choice: "enough
  history to actually debug a repeat crash".

## Open questions

1. **Where does the cap live?**
   - (a) In a module every host already imports, with no gate. This is my
     recommendation: it's one place, and new hosts are covered.
   - (b) Turn on `enableFiltering` for razer and p510. That pulls in the
     journald changes the constraints rule out.
   - (c) Set it separately in each host.
2. **Should p510 be deployed in this task**, or should it pick the cap up at
   its next routine deploy?
