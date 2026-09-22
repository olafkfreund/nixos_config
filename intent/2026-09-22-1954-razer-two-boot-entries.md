---
status: approved
issue: 1954
author: olafkfreund
---

# Intent: razer keeps at least two boot entries

## Problem

razer's boot menu has one NixOS entry, always. `hosts/razer/nixos/boot.nix`
sets `configurationLimit = 1`, so if a new generation does not boot, there
is no previous one to choose. `nixos-rebuild --rollback` still works, but
only from a system that boots. The boot menu is the fallback for the case
where it doesn't.

The limit is 1 because of space. The ESP is 511 MiB and cannot grow
without live media. Each generation costs about 145 MiB: a 131 MiB initrd
plus a 14 MiB kernel, measured 2026-09-22. A deploy writes the new
generation before it prunes old ones, so the peak is one generation more
than the limit. Only `nhs` runs the ESP guard (`scripts/check-boot-space.sh`);
`just deploy-via-p620`, `quick-deploy` and `just razer` do not. An overflow
mid-install has happened before: on 2026-08-12 razer was left running a
generation `/boot` could not boot.

Most of the initrd is NVIDIA firmware: 112 MiB of 221 MiB uncompressed.
About 30 MiB of that is for Turing GPUs (`gsp_tu10x.bin`,
`ucodes_tu10x.bin`). razer has an Ampere RTX 3080 Laptop (GA104) and only
uses the `ga10x` files.

## Proposed outcome

- The boot menu on razer lists at least two NixOS generations after every
  deploy, whichever deploy path is used.
- A deploy's peak ESP use leaves clear headroom, not a few MiB, so normal
  initrd growth does not push it into an overflow.
- Early NVIDIA KMS and PRIME sync behave exactly as today.

## Affected users and systems

- Host: razer only. p620 is AMD; p510 has a different NVIDIA card and
  config.
- Files: `hosts/razer/nixos/boot.nix` (the limit and its comment) and
  `hosts/razer/nixos/nvidia.nix` (the NVIDIA package, with the Turing
  firmware removed).
- User: olafkfreund, on the laptop.

## Constraints

- Keep NVIDIA in the initrd. Dropping early KMS was declined in August for
  PRIME sync, and that decision stands.
- The ESP is not resized. That needs live media.
- Removing firmware must not affect the running system: razer's GPU must
  still load its `ga10x` GSP firmware after boot.
- razer deploys go through p620 (`just deploy-via-p620 razer`).
- The first boot on the new config needs a real reboot to prove itself,
  with the old entry as the way back if it fails.

## Open questions

- The NVIDIA driver package becomes an override, so the driver and open
  kernel module build on p620 rather than coming from cache. They are
  unfree, so they already build locally. Is that acceptable?
- Should the note in `check-boot-space.sh` about razer's 150 MiB initrds be
  updated to the new size, or left as a record?
