---
status: draft
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

Approved decisions: delete the never-working `storage-optimizer` service, script and log dir; move the four
`vm.dirty_*` values into the module's `boot.kernel.sysctl` per `profile` (performance 5/10/1500/500, balanced
10/20/1500/3000, reliability 5/10/500/1000; the two ratios gated on `filesystemOptimization.enable &&
cacheOptimization`); delete `memory.nix`'s never-effective 3/2; remove the dead per-device options with
`mkRemovedOptionModule`; keep tmpfs, fstrim, smartd and packages. p620's runtime values stay 10/5/1500/500/3.

## Steps

1. `modules/storage/performance-optimization.nix`: delete :118-320 (service + script) and :323-325 (log dir);
   rewrite the sysctl block (:350-371) per the summary without the inner `mkIf`; replace the option declarations of
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

3. Docs (Claude): any `docs/` page describing the storage optimizer (grep `storage-optimizer`,
   `performanceOptimization`).

## Tests

Spec Verification: razer and p510 `IDENTICAL`; p620 sysctl values equal the live baseline; p620 `fileSystems` for
`/tmp`, `/var/tmp`, `/dev/shm` identical; p620 units differ only by `storage-optimizer`; p620 toplevel builds.
deadnix/statix; CI; `@codex review`.

## Rollback

Revert the squash commit.
