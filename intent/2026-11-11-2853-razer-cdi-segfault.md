---
status: approved
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

Without them, `nvidia-ctk` cannot find the driver libraries, the hook or
an ld cache on NixOS (there is no `/etc/ld.so.cache`), and a cgo bug in
`nvidia-ctk` 1.20.1 on that lookup-failure path segfaults. The override also
drops the upstream `jq` step that adds the NixOS driver/glibc mounts to the
spec, and removes the toolkit's `tools` output (`nvidia-cdi-hook`) from
razer's closure. Today it is not on the host at all.

Checked on razer on 2026-11-11, with nvidia-container-toolkit 1.20.1 and
driver 615.78.08 (kernel module and userspace match, so this is no
mismatch): the same `nvidia-ctk` with all three flags restored exits 0 and
writes a spec with devices `gpu0` and `all`. The remaining `nvsandboxutils`
/ egl warnings did not stop generation. Which of the three flags matters
most was not isolated, because they were restored together.

The wrapper's `|| echo "skipped (driver mismatch…)"` turns every failure,
this crash included, into success with a misleading message. It was added
so a driver bump could not fail a switch. That risk is real: on an nvidia
bump the unit's `ExecStart` changes, so a switch re-runs it against the
still-loaded old kernel module. It then fails with an NVML mismatch, and
`switch-to-configuration` exits 4, which the deploy wrapper treats as a
failure and rolls back. Removing the wrapper alone brings that back.

## Proposed outcome

- After a razer boot or a normal switch, the upstream spec
  `/run/cdi/nvidia-container-toolkit.json` exists and lists the GPU and
  `all`, and `docker`/`podman run --device nvidia.com/gpu=all … nvidia-smi`
  sees the GPU.
- The generator uses the nixpkgs script with its flags, mounts and closure,
  not a hand-written copy.
- When the generator runs and fails (at boot, or run by hand), the unit is
  **failed** with the real error. It does not report success, and it does
  not stop docker or podman.
- A switch that only changes the driver (before the next boot) does not
  exit 4 because of this unit. Leaving the old spec in place until then is
  acceptable.
- razer is deployed with the fix, and the spec and a GPU container are
  checked on the host.

## Affected users and systems

- razer only: `hosts/razer/nixos/nvidia.nix`. docker and podman are both
  enabled there; no containers use the GPU today.
- p510 and p620 are unchanged. p510 already uses the upstream script.

## Constraints

- A failed generator must not block a razer switch or stop docker/podman.
  A failed unit at switch time gives exit 4, which can roll back a deploy
  (see the deploy-rollback note).
- Use the upstream script. Don't copy its flags.
- The mechanism (unit wiring, when the unit re-runs) belongs in the spec.
  p510's `requiredBy` → `wantedBy`/`before` re-wiring
  (`hosts/p510/nixos/resilience.nix:117-127`) keeps the runtimes up, but on
  its own it does **not** prevent exit 4.
- razer builds on p620 (`just deploy-via-p620 razer`). Announce on the agent
  bus before deploying.
- No p510 build or deploy.

## Open questions

1. Keep CDI on razer, or turn `hardware.nvidia-container-toolkit` off? No
   container uses the GPU there today, and turning it off removes the unit,
   the 180 s `udevadm settle` and the switch-time risk entirely. Proposed:
   keep it, since the issue asks for working GPU containers. This is your
   call.
2. Device names: upstream defaults to `index` (`nvidia.com/gpu=0`). The old
   wrapper asked for `type-index` (`gpu0`), but no spec was ever written, so
   nothing depends on it. Proposed: the upstream default.
3. Share the unit wiring with p510 in a module? Proposed: no. Keep it local
   to razer, because a shared module changes p510's evaluation, and p510 may
   not be built without your OK. Sharing it is a possible follow-up.

## Review notes

The draft was reviewed by Codex (gpt-6.1-sol) and agy (model not reported),
read-only. Both flagged the exit-4 contradiction and the wrong spec
path/name in the first draft; both points were confirmed against the
nixpkgs module and fixed above. Advice only, not approval.
