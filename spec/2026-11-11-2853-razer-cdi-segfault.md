---
status: draft
issue: 2853
intent: intent/2026-11-11-2853-razer-cdi-segfault.md
---

# Spec: razer CDI generator segfaults, and the wrapper hides it

## Design

All changes are in `hosts/razer/nixos/nvidia.nix`.

1. **Delete the `ExecStart` override** (lines 112-120, the comment and the
   `nvidia-cdi-generator-safe` `writeShellScript`). The unit then runs the
   nixpkgs `cdi-generate.nix` script, with `--library-search-path`,
   `--nvidia-cdi-hook-path`, `--ldconfig-path`, the NixOS mount step and the
   `tools` output in the closure. It writes
   `/run/cdi/nvidia-container-toolkit.json` with the default `index` names
   (`nvidia.com/gpu=0`, `=all`). A real failure ends the unit as `failed`,
   because the script uses `set -e -u -o pipefail`.

2. **Re-wire the unit in its place**, so a failure cannot stop a runtime or
   a switch:

   ```nix
   # The generator must not take docker/podman down or fail a switch (#2853).
   # On an nvidia bump the new driver can't talk to the loaded kernel module
   # until reboot, so don't re-run it at switch; the old spec stays valid
   # until then. Same runtime wiring as p510 (resilience.nix).
   systemd.services.nvidia-container-toolkit-cdi-generator = {
     restartIfChanged = false;
     requiredBy = lib.mkForce [ ];
     wantedBy = [ "docker.service" "podman.service" ];
     before = [ "docker.service" "podman.service" ];
   };
   ```

   - `restartIfChanged = false` is what prevents exit 4. A driver bump
     changes `ExecStart`, and with this setting `switch-to-configuration`
     leaves the active (exited) unit alone instead of re-running it against
     the old kernel module. The unit next runs at boot, where driver and
     module match.
   - `requiredBy = mkForce [ ]` + `wantedBy`/`before` is p510's fix
     (`hosts/p510/nixos/resilience.nix:117-127`): a failed generator
     degrades GPU containers instead of stopping docker/podman, and the
     spec exists before either runtime starts. The upstream
     `wantedBy = [ "multi-user.target" ]` merges in unchanged, which also
     covers daemonless `podman`.
   - The runtime units are listed literally, as on p510. razer enables both
     (eval: `virtualisation.docker.enable = true`,
     `virtualisation.podman.enable = true`).

Approved intent decisions carried over: CDI stays on; upstream `index`
naming; wiring local to razer, no shared module, p510 untouched.

## Alternatives rejected

- **Keep the wrapper and add the three flags.** It copies upstream's
  script, which drifts on the next nixpkgs change, still skips the mount
  step, and still turns failures into success.
- **`ExecStart = "-…"` or `SuccessExitStatus`.** They avoid exit 4 by
  hiding the failure at boot too, which is the bug this issue is about.
- **Only p510's wiring, without `restartIfChanged = false`.** It keeps the
  runtimes up, but a driver bump still fails the unit at switch and gives
  exit 4 (intent, constraints).
- **Turn `hardware.nvidia-container-toolkit` off.** Rejected at the intent
  gate: the owner keeps CDI.
- **A shared module for razer and p510.** Rejected at the intent gate: it
  changes p510's evaluation.

## Risks

- **Spec not regenerated on a non-driver change.** With
  `restartIfChanged = false`, a toolkit-only bump or a change to `mounts`
  takes effect at the next boot or a manual restart of the unit. Driver
  changes need a boot anyway; the others are rare. Accepted.
- **The deploying switch itself does not re-run the unit** (same
  setting), so `/run/cdi` stays empty until the unit is started by hand or
  razer boots. Verification starts it by hand.
- **docker/podman may be restarted on this deploy.** The changed
  `requires`/`wants` links can make `switch-to-configuration` restart
  them. razer runs no containers today (`docker ps` empty on 2026-11-11).
- **`udevadm settle --timeout=180`** from upstream already runs today; it
  is unchanged.
- razer only. p510 and p620 evaluations are not touched.

## Verification

1. Eval on p620:
   - `ExecStart` of the unit is the upstream `nvidia-cdi-generator` script
     (no `nvidia-cdi-generator-safe`).
   - `restartIfChanged = false`, `requiredBy = [ ]`, `before` and
     `wantedBy` contain both runtimes.
2. `just test-host razer` builds.
3. Deploy with `just deploy-via-p620 razer`, after a bus announcement. The
   switch has no failed unit from this generator.
4. On razer (announced): start the unit, then check
   - `systemctl show -p Result,ActiveState` is `success` / `active`,
   - `/run/cdi/nvidia-container-toolkit.json` lists `0` and `all`,
   - the journal for that run has no `SIGSEGV`,
   - `docker run --rm --device nvidia.com/gpu=all ubuntu:24.04 nvidia-smi`
     and the same with `podman` print the GPU.
5. The failure path (unit `failed` on a real error) follows from upstream's
   `set -e` and is not forced on the host. Shown by eval/reading only.
