---
status: approved
issue: 2156
intent: intent/2026-10-04-2156-games-ssd-failing.md
---

# Spec: p620 keeps working while its /mnt/games SSD is failing

The intent's open questions had no answers on approval. These are the
defaults taken here, all changeable at this review:

1. **k3d:** keep it, and move its storage to `/mnt/data`.
2. **Mount at boot:** keep mounting, but with short timeouts.
3. **Data rescue:** nothing needed. The win11 image is already on
   `/mnt/data` (`/mnt/data/virtual_disks/win11.qcow2`), not on sda.
4. **Replacement:** assumed to come later; swapping back is documented here.

## Design

### 1. Build dir to the NVMe, runners from 4 to 2

`hosts/p620/configuration.nix:84`: change `buildDir` to `"/var/lib/nix-build"`,
which is on `/` (NVMe), and `instances` (line 102) from 4 to 2.

Rewrite the comment block above it (lines 64-83) to say why, in a few lines:
the SSD is failing (Issue #2156); the NVMe has about 208 GB free; two runners
peak at about 64 GB of VM images (each job is two 32 GB-disk VMs), which
leaves about 140 GB on `/`. That's the margin #1643 asked for, where four
runners (about 128 GB at peak) would not leave it. Keep the existing tradeoff
note about one nix daemon short.

`/mnt/data` (sdb) was considered for the build dir instead. It has more space
(517 GB free), but it's the same Fanxiang S101Q model at the same age
(15,258 h). The VM-install write pattern is what broke sda, and putting it on
the twin drive invites the same failure.

### 2. k3d storage to /mnt/data

`hosts/p620/configuration.nix:492`: change `storageDir` to
`"/mnt/data/k3d/storage"`. That's a separate disk from `/`, which keeps PV
IOPS off the NVMe, as the original comment intended.

k3d writes are moderate, unlike VM installs, so the twin drive is acceptable
here. Update the comment.

As the existing comment warns, k3d doesn't re-bind an existing container, so
this takes a runtime migration (the plan's runtime steps):

1. Stop the cluster.
2. `rsync -a` the 34 GB from `/mnt/games/k3d/storage` to the new path, while
   sda still reads.
3. Recreate the cluster, so the containers bind the new path.
4. Verify with the `docker inspect` command in the comment.

### 3. Mount sda without letting it hang boot

`hosts/p620/nixos/hardware-configuration.nix:37-45`: keep `nofail`, `users`
and `exec`, and add:

- `x-systemd.device-timeout=10s`: a missing or dead device doesn't hold up
  boot for the default 90 s.
- `x-systemd.mount-timeout=60s`: an fsck or a journal replay that hangs
  doesn't hang boot.
- `noatime`: reads don't write access times. On 2026-10-04 a `du` alone
  aborted the journal and flipped the fs read-only through atime updates.

### 4. A stalled sda can't block writes to other disks

A udev rule matching sda by serial (`ID_SERIAL_SHORT=="MX_00000000000030717"`),
set in the same host file via `services.udev.extraRules`. It sets that
disk's `bdi/strict_limit=1` and `bdi/max_ratio=1`, the same settings applied
by hand today. The kernel then holds at most about 1% of the dirty limit for
sda, so a stall there throttles only writers to sda.

Matching by serial means the rule simply doesn't apply to a replacement
drive, so it can't leak onto healthy hardware.

Not chosen: lowering the global `vm.dirty_ratio`. A lower global cap makes a
single stalled disk reach it sooner and throttle every disk, which is the
opposite of what's wanted.

### 5. Swapping in a replacement

A short paragraph in the hardware file, next to the mount: when a new drive
replaces sda, update the UUID, delete the udev rule, and consider moving
`buildDir` back and `instances` to 4. Measure first.

## Alternatives rejected

- **Stop mounting sda at boot (`noauto`):** the games become unreachable
  without a manual step, and with the timeouts above a dead drive costs
  boot at most 10-60 s.
- **Build dir on `/mnt/data`:** same model and age as the failing drive;
  see section 1.
- **Keep four runners on the NVMe:** about 128 GB of VM images at peak
  against 208 GB free is the #1643 failure waiting to happen.
- **Drop k3d:** it's active (`k3d-cluster-bootstrap`), and there's no reason
  to lose it.

## Risks

- **CI capacity halves on p620** until the drive is replaced. p510's runners
  share the pool, so jobs queue longer but don't fail.
- **The k3d migration** needs a cluster recreate, so the factory namespace's
  pods are down for a few minutes. ArgoCD re-syncs, and factory Secrets are
  re-seeded from agenix (`factorySecrets.enable`). The PV data is copied
  first; `rsync` from a drive that fails *writes* should still read.
- **The udev rule** needs the attribute names to be right. Verify
  `cat /sys/block/sda/bdi/max_ratio` = 1 after a deploy and after a re-plug.
- **Builds move back to the NVMe** after a few hours elsewhere. The nix store
  is on the NVMe too, so outputs are renamed rather than copied: faster.

## Verification

- `just test-host p620` builds.
- After deploying:
  - `nix config show build-dir` returns `/var/lib/nix-build`;
  - two runner units are active, not four (check the GitHub runner list via
    `gh api`);
  - `cat /sys/block/sda/bdi/{strict_limit,max_ratio}` returns `1 1`;
  - `systemctl show mnt-games.mount -p TimeoutUSec` reports 1 min.
- k3d: `docker inspect` shows the PV mount source under `/mnt/data/k3d/storage`;
  the factory pods are Running; ArgoCD apps are Synced.
- Reboot test (at your convenience; p620 is a workstation): boot completes,
  and `/mnt/games` mounts or fails within the timeouts without blocking login.
