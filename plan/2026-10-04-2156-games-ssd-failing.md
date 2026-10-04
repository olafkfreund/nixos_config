---
status: draft
issue: 2156
spec: spec/2026-10-04-2156-games-ssd-failing.md
---

# Plan: p620 keeps working while its /mnt/games SSD is failing

## Decisions (from the approved spec)

1. Build dir to the NVMe at `/var/lib/nix-build`, and runners from 4 to 2
   (about 64 GB peak vs 208 GB free).
2. k3d storage to `/mnt/data/k3d/storage`, with a runtime migration
   (stop, rsync 34 GB, recreate, verify).
3. Keep mounting `/mnt/games`, adding `x-systemd.device-timeout=10s`,
   `x-systemd.mount-timeout=60s` and `noatime`.
4. A udev rule matching sda's serial `MX_00000000000030717`: set
   `bdi/strict_limit=1` and `bdi/max_ratio=1`.
5. A swap-back note next to the mount.

## Steps

1. `hosts/p620/configuration.nix`:
   - line 84: `buildDir = "/var/lib/nix-build";`
   - line 102: `instances = 2;`
   - replace the comment blocks above both (64-83 and 86-101) with a short
     note: the SSD is failing (Issue #2156); NVMe headroom; two runners peak
     at about 64 GB; restore four after a replacement and a measurement.

   Verify by `nix eval .#nixosConfigurations.p620.config.nix.settings.build-dir`
   (expect `/var/lib/nix-build`).

   Traps:
   - the runner module sets both `build-dir` and the nix-daemon `TMPDIR`, so
     use only the option, never a raw `nix.settings` override;
   - check that the module creates the dir (tmpfiles) with the right
     ownership; if not, add a `systemd.tmpfiles.rules` entry in the host
     (root 0755, like `/mnt/games/nix-build`).
2. `hosts/p620/configuration.nix:492`:
   `storageDir = "/mnt/data/k3d/storage";`. Update the comment: a separate
   disk from `/`, moved off the failing sda (Issue #2156), and the existing
   VERIFY note stays.

   Verify by eval of `config.modules.containers.k3d.storageDir`.
3. `hosts/p620/nixos/hardware-configuration.nix:37-45`: add `"noatime"`,
   `"x-systemd.device-timeout=10s"` and `"x-systemd.mount-timeout=60s"` to
   `options`. Add a three-line comment: failing drive, the swap-back steps
   (new UUID, drop the udev rule, consider `buildDir`/`instances`).

   Then add `services.udev.extraRules` in the same file:
   with match keys `ACTION=="add|change"`, `SUBSYSTEM=="block"`,
   `ENV{DEVTYPE}=="disk"` and `ENV{ID_SERIAL_SHORT}=="MX_00000000000030717"`
   (confirmed with udevadm), setting `ATTR{bdi/strict_limit}="1"` and
   `ATTR{bdi/max_ratio}="1"`.

   Verify by `just check-syntax` and `just test-host p620`.

   Traps:
   - check the serial key with `udevadm info /dev/sda | grep SERIAL`, since
     `ID_SERIAL_SHORT` may differ from smartctl's form;
   - hardware-configuration.nix is hand-edited here, not regenerated, so
     that's fine.
4. Build p620. Commit one per step, then open a PR linking all three
   artifacts.

Runtime, after merge (p620; announce on the bus first: runner and k3d
changes are disruptive):

1. Deploy p620.
   - The switch remounts `/mnt/games` with the new options and restarts
     the runners as two.
   - Check: `nix config show build-dir`, the runner unit count,
     `cat /sys/block/sda/bdi/{strict_limit,max_ratio}`, and
     `findmnt -o OPTIONS /mnt/games` (contains `noatime`).
   - The manual NVMe bind over `/mnt/games/nix-build` is no longer needed;
     it disappears at the next unmount or reboot.
2. k3d migration:
   - stop the cluster (`k3d cluster stop` for the factory cluster, name from
     the module);
   - `sudo rsync -aHAX --info=progress2 /mnt/games/k3d/storage/ /mnt/data/k3d/storage/`;
   - recreate the cluster through the module's bootstrap
     (`systemctl restart k3d-cluster-bootstrap`, which needs a delete first
     because k3d doesn't re-bind);
   - verify with the `docker inspect` from the comment; pods Running; ArgoCD
     Synced.
   - Keep the old copy on sda until verified, then leave it; don't delete
     from the failing disk.

   Traps:
   - read the k3d module (`modules/containers/k3d*`) for the cluster name
     and whether bootstrap recreates;
   - see memory: serverlb startup deadlock, and bind mounts don't follow
     config.

## Tests

- `just test-host p620` passes.
- After the deploy: build-dir `/var/lib/nix-build`; 2 runners online in the
  GitHub API; bdi values `1 1`; mount options include `noatime`; a local
  `nix build` of anything succeeds with sda unmounted.
- k3d: PV mounts under `/mnt/data/k3d/storage`; factory pods Running.
- Optional reboot test whenever convenient: boot doesn't stall on sda.

## Rollback

- Revert the PR and redeploy. The old paths still exist.
- k3d: the old storage is untouched on sda; recreate with the old
  `storageDir`.
