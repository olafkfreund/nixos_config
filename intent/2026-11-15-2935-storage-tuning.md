---
status: approved
issue: 2935
author: olafkfreund
---

# Intent: one declarative owner for storage tuning

## Problem

`modules/storage/performance-optimization.nix` (enabled only on p620) runs a `storage-performance-optimizer` service
that is
supposed to tune every disk (scheduler, `nr_requests`, read-ahead, NVMe polling, write-back throttling, hdparm
caches). The unit has no `path`, so `lsblk` and `awk` fail with "command not found" on every run
(`/var/log/storage-tuning/optimizer.log`, July 2025 to now), and the per-device part has never run. Its failures
are suppressed while it prints success. The only thing it does is write four `vm.dirty_*` values to `/proc/sys`,
two of which silently override `hosts/p620/nixos/memory.nix` (`vm.dirty_ratio` 3 → 10,
`vm.dirty_background_ratio` 2 → 5), and two of which the module also sets through `boot.kernel.sysctl`. Option
names lie too: `nvmeOptimization.multiQueue` disables write-back throttling.

## Proposed outcome

Every storage setting p620 actually has today comes from one declarative place, the per-device options that never
did anything are gone, and nothing fails silently. p620's effective runtime values do not change; razer and p510
build the identical system.

## Affected users and systems

p620 (the only host that enables the module); the module is imported on all three hosts.

## Constraints

- Runtime-preserving on p620: live `vm.dirty_ratio` 10, `vm.dirty_background_ratio` 5,
  `dirty_writeback_centisecs` 1500, `dirty_expire_centisecs` 500, `page-cluster` 3, the `/var/tmp` and `/dev/shm`
  tmpfs mounts and `/tmp` on disk, fstrim and smartd all stay as they are.
- razer and p510: toplevel `.drv` identical.
- No deploy in this task.

## Open questions

Resolved by the owner's preservation rule: keep the live 10/5, not `memory.nix`'s never-effective 3/2 (a one-line
change later if wanted).
