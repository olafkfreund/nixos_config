---
status: draft
issue: 2935
intent: intent/2026-11-15-2935-storage-tuning.md
---

# Spec: one declarative owner for storage tuning

## Design

1. **Delete the `storage-optimizer` service and its script** (`performance-optimization.nix:118-320`) and the
   `/var/log/storage-tuning` tmpfiles rule (:323-325). The per-device work never ran; the `/proc/sys` writes move to
   sysctl (2).
2. **`boot.kernel.sysctl`** in the module, under `cfg.enable`, owns all four `vm.dirty_*` values plus `page-cluster`,
   per `profile` exactly as the script's `case` did (performance 5/10/1500/500, balanced 10/20/1500/3000,
   reliability 5/10/500/1000), gated on `filesystemOptimization.enable && cacheOptimization` for the two ratios as the
   script did. Remove the redundant inner `mkIf` (:350). `dirty_expire_centisecs` keeps its `mkDefault`.
3. **`hosts/p620/nixos/memory.nix:15-16`**: delete `vm.dirty_ratio = 3` and `vm.dirty_background_ratio = 2` (they
   would conflict at equal priority, and they never took effect) with a one-line comment pointing at the module.
4. **Options**: remove `ioSchedulerOptimization`, `filesystemOptimization.readaheadOptimization`, `nvmeOptimization`
   and `diskCacheOptimization` with `lib.mkRemovedOptionModule` and a message saying they never ran (#2935); delete
   their settings from `hosts/p620/configuration.nix:814-837`. Keep `enable`, `profile`,
   `filesystemOptimization.{enable,cacheOptimization}` and `tmpfsOptimization` (with its p620 comment).
5. Keep fstrim, smartd and the package list (:374-401) unchanged.

## Alternatives rejected

- Rebuild the per-device knobs as udev rules: turns on settings p620 has never had, and the SSD `none` scheduler rule
  collides with `hosts/p620/nixos/hardware-configuration.nix:116` (NVMe `bfq`).
- Keep the script and add a `path`: makes 16-month-dead behaviour suddenly live.

## Risks

- `mkRemovedOptionModule` throws if any host still sets a removed option: caught at evaluation (p620 edited in the
  same commit).
- A `switch` restarts `systemd-sysctl`; with the values now declarative they are applied at boot and on switch.

## Verification

- razer and p510: `scripts/config-snapshot.sh` `IDENTICAL`.
- p620: `nix eval --json .#nixosConfigurations.p620.config.boot.kernel.sysctl` filtered to `vm.dirty_*` and
  `vm.page-cluster` equals the live values (10, 5, 1500, 500, 3) recorded before the change; `config.fileSystems`
  for `/tmp`, `/var/tmp`, `/dev/shm` identical before/after; `systemd.units` lose only `storage-optimizer.*`;
  smartd/fstrim units identical; the toplevel builds.
