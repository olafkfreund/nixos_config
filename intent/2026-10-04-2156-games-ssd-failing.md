---
status: approved
issue: 2156
author: olafkfreund
---

# Intent: p620 keeps working while its /mnt/games SSD is failing

## Problem

p620's `/mnt/games` (sda1, Fanxiang S101Q 1 TB QLC SSD with no DRAM, SATA
port ata4) fails sustained writes:

- write timeouts, the link dropping to 1.5 Gbps / UDMA/33, and the ext4
  journal aborting into read-only;
- three times on 2026-10-04: 17:40, 18:09 and 18:32;
- a 20 GB write test failed with link power management off and NCQ off.

SMART reports PASSED, and the PHY CRC counters are 0. The drive or its
port/controller is failing; it isn't configuration.

The p620 config still treats it as primary storage:

- `hosts/p620/configuration.nix:84`: `buildDir = "/mnt/games/nix-build"`.
  This is the nix `build-dir` and the nixarchy runners' VM installs.
- `hosts/p620/configuration.nix:492`: k3d `storageDir = "/mnt/games/k3d/storage"`.
- `hosts/p620/nixos/hardware-configuration.nix:37`: mounted at boot.

When it stalls, local builds and CI jobs on p620 fail. In one stall about
18 GB of unwritten data for sda piled up toward the global dirty-page limit,
and processes writing to the NVMe blocked too, so the desktop nearly froze.
Today's safeguards (an NVMe bind mount over `nix-build`, a dirty cap for sda,
LPM `max_performance`) are runtime-only and lost on reboot.

## Proposed outcome

- After any reboot, p620's builds, CI runners and k3d don't write to sda.
- p620 boots and stays responsive whatever state sda is in, including dead
  or missing.
- A stall on sda can't block writes to other disks.
- The games and VM data on sda stay reachable while the drive still reads,
  until you replace it.
- When a replacement drive goes in, pointing things back at it is a small,
  documented change.

## Affected users and systems

p620 only:

- nix builds;
- both nixarchy runners (the CI pool shared with p510);
- k3d on p620;
- the games and win11 VM data on `/mnt/games`.

## Constraints

- The NVMe root has about 208 GB free. The runners' install checks need
  about 16 GB per VM, with up to two running at once, so the build dir fits
  there. #1643 moved it off `/` for space, so the spec has to size it.
- Don't lose data on sda that can still be read.
- p620 deploys need the agent bus announcement. The runners are shared CI,
  so moving their build dir is announced too.

## Open questions

1. **k3d storage:** k3d is active on p620 (`k3d-cluster-bootstrap` ran at
   boot) and holds 34 GB on sda. Move it to the NVMe (it fits in the 208 GB
   free, next to the build dir), or decide that k3d on p620 is no longer
   needed?
2. **Mount at boot:** keep mounting sda (`nofail` plus a short device
   timeout, so a dead drive can't hold up boot), or stop mounting it at boot
   (`noauto`, mounted by hand) until it's replaced?
3. **Data rescue:** copy the important parts (the win11 VM image, any saves)
   to the NVMe or p510 now, while the drive still reads?
4. **Replacement:** is a new drive planned? If so, the design can assume a
   swap rather than a long-term workaround.
