---
status: draft
issue: 2853
spec: spec/2026-11-11-2853-razer-cdi-segfault.md
coders:
  1: coder # one small, fully specified edit; default routing
reviewers:
  - codex # second read of the unit semantics (agent-team default)
  - agy # same (agent-team default)
---

# Plan: razer CDI generator segfaults, and the wrapper hides it

Approved decisions (intent + spec):

- Cause: `hosts/razer/nixos/nvidia.nix` overrides the generator's
  `ExecStart` with `lib.mkForce`, dropping the nixpkgs script's
  `--library-search-path`, `--nvidia-cdi-hook-path` and `--ldconfig-path`,
  its mount step and the `tools` closure. `nvidia-ctk` segfaults, and the
  wrapper's `|| echo` reports success.
- Delete the override and use the nixpkgs script. CDI stays on razer.
  Default device names (`index`: `nvidia.com/gpu=0`, `=all`). The spec
  file is `/run/cdi/nvidia-container-toolkit.json`.
- In its place: `restartIfChanged = false` (a driver bump does not re-run
  an **active** generator at switch, so no exit 4), and p510's wiring
  `requiredBy = mkForce [ ]` + `wantedBy`/`before` docker and podman (a
  failed generator does not stop either runtime).
- Accepted: an already **failed** generator is re-run by every switch and
  exits 4 on failure. That is the visible error, by design.
- razer only; no shared module; p510 not built or deployed.

## Steps

1. `hosts/razer/nixos/nvidia.nix:112-120`: replace the comment block and
   the `systemd.services.nvidia-container-toolkit-cdi-generator.serviceConfig.ExecStart = lib.mkForce (pkgs.writeShellScript "nvidia-cdi-generator-safe" …);`
   assignment with exactly:

   ```nix
   # The CDI generator must not take docker/podman down or fail a switch
   # (#2853). After an nvidia bump the new driver can't talk to the loaded
   # kernel module until reboot, so don't re-run it at switch; the old spec
   # stays valid until then. Runtime wiring as on p510 (resilience.nix).
   systemd.services.nvidia-container-toolkit-cdi-generator = {
     restartIfChanged = false;
     requiredBy = lib.mkForce [ ];
     wantedBy = [ "docker.service" "podman.service" ];
     before = [ "docker.service" "podman.service" ];
   };
   ```

   → verify with step 2.
   Traps: keep `lib` and `pkgs` in the file's argument list only if they
   are still used elsewhere (`pkgs` is; `lib` is used by `mkForce`).
   Don't touch `hardware.nvidia-container-toolkit.enable` (line 81) or the
   udev rules below. The commit hook runs nixfmt; let it format.

2. Eval and build (lead), from the worktree:

   ```bash
   C=.#nixosConfigurations.razer.config.systemd.services.nvidia-container-toolkit-cdi-generator
   nix eval --raw $C.serviceConfig.ExecStart        # .../bin/nvidia-cdi-generator, no "-safe"
   nix eval --json $C.restartIfChanged              # false
   nix eval --json $C.requiredBy                    # []
   nix eval --json $C.wantedBy                      # docker, podman, multi-user.target
   nix eval --json $C.before                        # docker, podman
   nix eval --raw .#nixosConfigurations.razer.config.systemd.units.\"nvidia-container-toolkit-cdi-generator.service\".text | grep X-RestartIfChanged=false
   just check-syntax
   just test-host razer
   ```

   Traps: `set -o pipefail` around any `nix build | tail`.

3. Commit (lead) `fix(razer): use the upstream CDI generator script and stop it failing a switch (#2853)`.
   Open the PR linking intent, spec and plan; run the Opus review
   (fresh agent: plan path + `git diff origin/main`) and the Codex and agy
   reviews on the diff. Merge once clean.
   Traps: write the commit body and PR text to files (`-F`,
   `--body-file`), because the bus guard matches words in command text.

4. Deploy (lead) from `~/.config/nixos` on `main` after the merge:
   check `nhs` is not running there, `git pull --ff-only`, read
   `#agents:freundcloud.org.uk`, post the razer deploy (about 10 min), then
   `AGENT_BUS_ANNOUNCED=1 just deploy-via-p620 razer`.
   Expect: no failed unit from the generator. A cosmetic exit 4 from
   syncthing on razer is known; read the `units failed:` line.
   Traps: never deploy from the task worktree; leave the checkout on
   `main`.

5. Runtime check on razer (lead, announced in the same post), one SSH call:

   ```bash
   sudo systemctl restart nvidia-container-toolkit-cdi-generator
   systemctl show -p Result,ActiveState,ExecMainStartTimestamp nvidia-container-toolkit-cdi-generator
   jq -r '.devices[].name' /run/cdi/nvidia-container-toolkit.json   # 0, all
   journalctl -u nvidia-container-toolkit-cdi-generator --since -5min | grep -c SIGSEGV   # 0
   docker run --rm --device nvidia.com/gpu=all docker.io/library/ubuntu:24.04 nvidia-smi -L
   sudo podman run --rm --device nvidia.com/gpu=all docker.io/library/ubuntu:24.04 nvidia-smi -L
   ```

   If only the docker run fails to resolve the device, restart docker once
   (announced) and retry: dockerd may have missed the recreated
   `/run/cdi`. Then remove the pulled image.
   Traps: `start` is a no-op on this active oneshot; it must be
   `restart`. Rootless podman is out of scope.

6. Close #2853 with the results, and post the outcome on the bus.

## Tests

- Step 2: every eval matches; `just test-host razer` exits 0.
- Step 4: the deploy has no failed generator unit.
- Step 5: `Result=success`, a fresh start time, devices `0` and `all`, no
  `SIGSEGV`, and both `nvidia-smi -L` print the GPU.
- Not tested on the host (reading only): failure path, driver-bump switch,
  boot path.

## Rollback

Revert the step 1 commit on `main` and deploy razer again
(`just deploy-via-p620 razer`), or switch razer to the previous generation
(`sudo nixos-rebuild switch --rollback` on razer). Nothing outside
`/run/cdi` holds state.
