---
status: approved
issue: 2935
spec: spec/2026-11-15-2935-storage-tuning.md
coders:
  1: codex  # module rewrite: delete the script, profile-based sysctl, mkRemovedOptionModule
  2: coder  # two host files: drop the removed options on p620, drop two lines in memory.nix
reviewers:
  - codex
  - agy
---

# Plan: one declarative owner for storage tuning

Approved decisions: delete the never-working `storage-performance-optimizer` service, script and log dir; move the four
`vm.dirty_*` values into the module's `boot.kernel.sysctl` per `profile` (performance 5/10/1500/500, balanced
10/20/1500/3000, reliability 5/10/500/1000; the two ratios gated on `filesystemOptimization.enable &&
cacheOptimization`); delete `memory.nix`'s never-effective 3/2; remove the dead per-device options with
`mkRemovedOptionModule`; keep tmpfs, fstrim, smartd and packages. p620's runtime values stay 10/5/1500/500/3.

## Steps

1. `modules/storage/performance-optimization.nix`: delete the whole `systemd = { ... }` block (:115-326: service,
   script, log dir); replace the sysctl block (:350-371) with (no inner `mkIf`, no "resource manager" comments):

   ```nix
   boot.kernel.sysctl = mkMerge [
     {
       "vm.dirty_writeback_centisecs" = { performance = 1500; balanced = 1500; reliability = 500; }.${cfg.profile};
       "vm.dirty_expire_centisecs" = mkDefault { performance = 500; balanced = 3000; reliability = 1000; }.${cfg.profile};
       "vm.page-cluster" = 3;
     }
     (mkIf (cfg.filesystemOptimization.enable && cfg.filesystemOptimization.cacheOptimization) {
       "vm.dirty_background_ratio" = { performance = 5; balanced = 10; reliability = 5; }.${cfg.profile};
       "vm.dirty_ratio" = { performance = 10; balanced = 20; reliability = 10; }.${cfg.profile};
       "vm.dirty_bytes" = null; # nixarchy sets these; null keeps the ratios the only owner (#2935)
       "vm.dirty_background_bytes" = null;
     })
   ];
   ```

   Then replace the option declarations of
   `ioSchedulerOptimization`, `filesystemOptimization.readaheadOptimization`, `nvmeOptimization`,
   `diskCacheOptimization` with removal stubs, one per option:

   ```nix
   imports = [
     (lib.mkRemovedOptionModule [ "storage" "performanceOptimization" "nvmeOptimization" ]
       "never ran: the optimizer unit had no PATH (#2935)")
   ];
   ```

   Drop now-unused `let` bindings (deadnix). → verify: `nix eval` p620 sysctl values below.
2. `hosts/p620/configuration.nix:814-837`: delete the four removed option blocks (keep `filesystemOptimization`
   with `enable` and `cacheOptimization` only, and `tmpfsOptimization` with its comment).
   `hosts/p620/nixos/memory.nix:15-16`: delete the two lines; add `# vm.dirty_ratio/background_ratio: set by
   storage.performanceOptimization (10/5, the live values; #2935)`.
   → verify: the five values are 10, 5, 1500, 500, 3:

   ```bash
   nix eval --json .#nixosConfigurations.p620.config.boot.kernel.sysctl --apply \
     's: { inherit (s) "vm.dirty_ratio" "vm.dirty_background_ratio" "vm.dirty_writeback_centisecs" "vm.dirty_expire_centisecs" "vm.page-cluster"; }'
   ```

3. Docs (Claude): any `docs/` page describing the storage optimizer (grep `storage-performance-optimizer`, `performance-optimization`,
   `performanceOptimization`).

## Tests

Spec Verification: razer and p510 `IDENTICAL`; p620 sysctl values equal the live baseline; p620 `fileSystems` for
`/tmp`, `/var/tmp`, `/dev/shm` identical; p620 units differ only by `storage-performance-optimizer`; p620 toplevel builds.
deadnix/statix; CI; `@codex review`.

## Rollback

Revert the squash commit.
