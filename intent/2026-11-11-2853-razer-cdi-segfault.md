---
status: draft
issue: 2853
author: olafkfreund
---

# Intent: razer CDI generator segfaults, and the wrapper hides it

## Problem

razer has no NVIDIA CDI spec. `/var/run/cdi` is empty, so
`--device nvidia.com/gpu=...` cannot work in docker or podman.

`nvidia-container-toolkit-cdi-generator.service` reports success, but
`nvidia-ctk cdi generate` segfaults on every run (SIGSEGV in cgo `free`, in
`dlopenLocator.Locate`, called from `getNvmlLib`). It has done so since at
least 2026-07-17, at boot as well as after a switch.

The cause is our own override. `hosts/razer/nixos/nvidia.nix:112-120`
replaces the unit's `ExecStart` with `lib.mkForce`, which throws away the
nixpkgs script (`nixos/modules/services/hardware/nvidia-container-toolkit/cdi-generate.nix`).
That script passes three flags our wrapper drops:

- `--library-search-path <nvidia-driver>/lib`
- `--nvidia-cdi-hook-path <toolkit.tools>/bin/nvidia-cdi-hook`
- `--ldconfig-path <glibc>/bin/ldconfig`

Without them, `nvidia-ctk` cannot find `libnvidia-ml` or the hook on NixOS,
and it has no `/etc/ld.so.cache` to fall back on. Those are the three
warnings logged just before the crash.

Checked on razer on 2026-11-11, with nvidia-container-toolkit 1.20.1 and
driver 615.78.08 (kernel module and userspace match): the same `nvidia-ctk`
with those three flags exits 0 and writes a spec with devices `gpu0` and
`all`. The remaining `nvsandboxutils` / egl warnings are harmless.

The wrapper's `|| echo "skipped (driver mismatch…)"` turns every failure,
this crash included, into a success with a misleading message. It was added
so a driver bump could not fail a switch. p510 solves the same problem
another way (`hosts/p510/nixos/resilience.nix:117-127`): it keeps the
upstream script, and turns upstream's `requiredBy` on docker and podman into
`wantedBy` + `before`. A failed generator then degrades GPU containers,
doesn't stop the runtime, and still shows as failed.

## Proposed outcome

- After a razer switch or boot, `/var/run/cdi/nvidia.yaml` exists and lists
  `nvidia.com/gpu=gpu0` and `=all`.
- The generator uses the nixpkgs script with its flags, not a hand-written
  copy.
- When the generator really fails (for example, a driver/library mismatch
  after an nvidia bump before a reboot), the unit shows as **failed** with
  the real error. It does not stop docker or podman, and it does not report
  success.
- razer is deployed with the fix, and the spec is checked on the host.

## Affected users and systems

- razer only: `hosts/razer/nixos/nvidia.nix`. docker and podman are both
  enabled there; no containers use the GPU today.
- p510 and p620 are unchanged. p510 already uses the upstream script.

## Constraints

- A failed generator must not block a razer switch or stop docker/podman.
  A failed unit at switch time gives exit 4, which can roll back a deploy
  (see the deploy-rollback note).
- Use the upstream script. Don't copy its flags.
- razer builds on p620 (`just deploy-via-p620 razer`). Announce on the agent
  bus before deploying.
- No p510 build or deploy.

## Open questions

1. Keep CDI on razer, or turn `hardware.nvidia-container-toolkit` off since
   nothing uses it? Proposed: keep it. The issue asks for it to work, and the
   fix is mostly a deletion.
2. Should p510's `requiredBy` → `wantedBy`/`before` re-wiring become a shared
   module both hosts import, or be repeated on razer? Proposed: repeat the
   few lines on razer now, and leave sharing it as a possible follow-up.
