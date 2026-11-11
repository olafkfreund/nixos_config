---
status: approved
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

2. **Re-wire the unit in its place**, so a failure cannot stop a runtime,
   and a driver bump cannot fail a switch:

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
     the old kernel module (`switch-to-configuration-ng/src/main.rs`,
     `handle_modified_unit`: an active unit with `X-RestartIfChanged=false`
     goes to `units_to_skip`). The unit next runs at boot, where driver and
     module match, either from `multi-user.target` or from upstream's
     `KERNEL=="nvidia"` udev rule (`default.nix:222-224`), both of which
     stay as they are.
   - **The guarantee is for an active unit only.** If the generator is
     already `failed` (it failed at boot, or someone restarted it between
     a driver bump and the next boot), every switch calls `reset-failed`,
     starts `multi-user.target`, re-runs the generator, and exits 4 if it
     fails again (`main.rs:2354-2356, 2565-2566, 2622-2684`). That is
     accepted on purpose: it only happens when the generator is genuinely
     broken on the running system, and a loud deploy failure is the
     visible error the intent asks for, not the hidden one this issue is
     about. The answer to it is to reboot or fix the cause, not to mask it.
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
  setting). The unit is active (exited) from the old wrapper's fake
  success, so `systemctl start` is a no-op; `/run/cdi` stays empty until
  the unit is **restarted** or razer boots. Verification restarts it.
- **A failed generator fails later switches** (exit 4), as described in
  Design. Accepted; reboot or fix the cause.
- **docker and its CDI watch.** The deploy does not restart docker or
  podman: `switch-to-configuration-ng` compares unit files and `.d`
  drop-ins only, not `.wants`/`.requires` links (`main.rs` `parse_unit`,
  `compare_units`). But restarting the generator deletes and recreates
  `/run/cdi` (`RuntimeDirectory = "cdi"`), and dockerd may miss the new
  spec until it is restarted. If the docker check fails on that, restart
  docker once (announced); razer runs no containers (`docker ps` empty on
  2026-11-11). At boot, `before` creates the spec first.
- **Rootless podman** cannot open `/dev/nvidia*` (`0664 root:video`)
  without `--group-add keep-groups`. Verification uses rootful
  `sudo podman`; rootless GPU use is out of scope.
- **`udevadm settle --timeout=180`** from upstream already runs today; it
  is unchanged.
- razer only. p510 and p620 evaluations are not touched.

## Verification

1. Eval on p620:
   - `ExecStart` of the unit is the upstream `nvidia-cdi-generator` script
     (no `nvidia-cdi-generator-safe`).
   - `restartIfChanged = false` and the rendered unit text has
     `X-RestartIfChanged=false`; `requiredBy = [ ]`; `before` has both
     runtimes; `wantedBy` has both runtimes and `multi-user.target`.
2. `just check-syntax`, then `just test-host razer` builds.
3. Deploy from `main` after the PR merges, with
   `just deploy-via-p620 razer` and a bus announcement. The switch reports
   no failed unit from this generator.
4. On razer (announced): **restart** the unit, then check
   - `systemctl show -p Result,ActiveState,ExecMainStartTimestamp` gives
     `success` / `active` with a start time after the restart,
   - `/run/cdi/nvidia-container-toolkit.json` lists `0` and `all`,
   - the journal for that run has no `SIGSEGV`,
   - `docker run --rm --device nvidia.com/gpu=all
     docker.io/library/ubuntu:24.04 nvidia-smi` and the same with
     `sudo podman` print the GPU.
5. Not exercised on the host, shown by reading only: the failure path
   (unit `failed` on a real error, from upstream's `set -e`); a driver bump
   switch being skipped (`main.rs` `handle_modified_unit`); the boot path
   (`before` + `udevadm settle`) until razer's next boot.

## Review notes

The draft was reviewed by Codex (gpt-6.1-sol) and agy (model not reported),
read-only. Confirmed and fixed: `start` is a no-op on the active oneshot
(now `restart`); dependency-link changes do not restart docker/podman;
`restartIfChanged = false` protects an active unit only (now stated, and
the failed-unit case accepted on purpose); rootless podman, the dockerd CDI
watch and extra eval checks added. Advice only, not approval.
