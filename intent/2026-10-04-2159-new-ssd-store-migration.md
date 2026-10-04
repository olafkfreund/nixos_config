---
status: draft
issue: 2159
author: olafkfreund
---

# Intent: put p620's new SSD to work, replacing /mnt/games and taking /nix/store

## Problem

1. **The `/mnt/games` SSD is failing** (sda, Fanxiang S101Q; Issue #2156).
   #2158 moved the nix build dir to the NVMe root, cut p620's CI runners from
   4 to 2, and moved k3d storage to `/mnt/data`. That's a stopgap: half the
   CI capacity, more pressure on the root NVMe, and k3d on the failing
   drive's twin model.
2. **`/nix/store` lives on the root NVMe filesystem** (`/`, ext4, 916 GB,
   662 GB used, 77%), sharing space and write bandwidth with everything else
   on `/`. That includes, since #2158, the build dir and the runner VM
   installs. The store's size hasn't been measured yet (`du` exceeds 100 s).

A new 1 TB SSD arrives on 2026-10-05.

## Proposed outcome

- **The new SSD takes over from sda.** The games data is migrated (whatever
  can still be read from sda), and sda is retired.
- **`/nix/store` lives on its own filesystem** and keeps working through
  rebuilds, garbage collection, rollbacks and boot.
- **The root NVMe has comfortable headroom again,** so the build dir and
  four runners have room, or move to the new disk. Either way, CI capacity on
  p620 goes back to four runners.
- **k3d storage ends up on a disk chosen on purpose,** not a stopgap.
- **Every step can be rolled back** until the old copies are deleted.

## Affected users and systems

p620:

- the nix store and nix-daemon;
- boot (initrd mounts, the bootloader's generations);
- the nixarchy runners (shared CI with p510);
- k3d;
- the games data.

## Constraints

- **Moving `/nix/store` is the riskiest change here.** The store must be
  mounted before anything in it runs, so it has to be an early (initrd)
  mount. A wrong mount means an unbootable system. The plan needs a rehearsal
  or a fallback boot entry, and must keep the old store until the new one has
  booted.
- **p620 deploys and reboots need the agent bus announcement,** and are done
  while the user is at the machine.
- **The new disk's model:** prefer DRAM-cache / TLC. The old drives are
  QLC without DRAM, which is what failed under sustained writes.
- **Don't lose any data from sda** that can still be read.

## Open questions

1. **Which SSD is it (model, SATA or NVMe)?** That decides the port, the
   speed, and whether it should hold the store (fast, random read-heavy) or
   bulk data (games, VM installs).
2. **Does it go in sda's SATA port?** That port and cable are unproven, so
   another port is safer, and a cable swap tells us whether sda was
   port-related.
3. **What goes where on the new 1 TB?** For example: store plus build dir;
   or games plus build dir plus k3d, with the store staying on the NVMe.
   The store's size decides this, and the spec measures it first.
4. **What's the main goal of moving the store:** freeing NVMe space, or
   isolating its I/O? If the new disk is SATA, the store would get *slower*
   than on NVMe, which argues for moving the bulk data instead and leaving
   the store on NVMe.
