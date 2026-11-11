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
   the `serviceConfig.ExecStart = lib.mkForce (pkgs.writeShellScript
   "nvidia-cdi-generator-safe" …)` assignment on
   `systemd.services.nvidia-container-toolkit-cdi-generator` with exactly:

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

2. Eval and build (lead), on p620 (this host), from the worktree:

   ```bash
   C=.#nixosConfigurations.razer.config.systemd.services.nvidia-container-toolkit-cdi-generator
   nix eval --raw $C.serviceConfig.ExecStart        # .../bin/nvidia-cdi-generator, no "-safe"
   nix eval --json $C.restartIfChanged              # false
   nix eval --json $C.requiredBy                    # []
   nix eval --json $C.wantedBy                      # docker, podman, multi-user.target
   nix eval --json $C.before                        # docker, podman
   nix eval --raw .#nixosConfigurations.razer.config.systemd.units.\"nvidia-container-toolkit-cdi-generator.service\".text | grep X-RestartIfChanged=false
   nix-instantiate --parse hosts/razer/nixos/nvidia.nix >/dev/null
   just test-host razer
   ```

   Traps: `just check-syntax` doesn't return a failing status on errors,
   so `nix-instantiate --parse` is the gate. Use `set -o pipefail` around
   any `nix build | tail`.

3. Commit (lead) `fix(razer): use the upstream CDI generator script and stop it failing a switch (#2853)`.
   Open the PR linking intent, spec and plan, with `Refs #2853` (not
   `Closes`, so the issue stays open until step 5 passes). Run the Opus
   review (fresh agent: plan path + `git diff origin/main`) and the Codex
   and agy reviews on the diff. Merge once clean.
   Traps: write the commit body and PR text to files (`-F`,
   `--body-file`), because the bus guard matches words in command text.

4. Deploy (lead) from `~/.config/nixos` on `main` after the merge, on
   p620: check that `nhs` is not running there, `git pull --ff-only`, read
   `#agents:freundcloud.org.uk`, post the razer deploy plus the step 5
   checks (about 15 min), then
   `AGENT_BUS_ANNOUNCED=1 just deploy-via-p620 razer`.
   Expect: no failed unit from the generator. `just` exits non-zero on a
   switch exit 4. A cosmetic exit 4 from syncthing on razer is known, so
   read the `units failed:` line before deciding. Remove `./result`
   afterwards if the recipe left one.
   Traps: never deploy from the task worktree; leave the checkout on
   `main`.

5. Runtime check on razer (lead). Write this to the scratchpad as
   `cdi-check.sh` and run it with
   `AGENT_BUS_ANNOUNCED=1 ssh razer bash -s < cdi-check.sh`:

   ```bash
   set -eu -o pipefail
   u=nvidia-container-toolkit-cdi-generator
   img=docker.io/library/ubuntu:24.04
   sudo systemctl restart "$u"
   systemctl show -p Result,ActiveState,ExecMainStartTimestamp "$u"
   [ "$(systemctl show -P Result "$u")" = success ]
   inv=$(systemctl show -P InvocationID "$u")
   ! journalctl _SYSTEMD_INVOCATION_ID="$inv" --no-pager | grep -q SIGSEGV
   [ "$(jq -r '[.devices[].name] | sort | join(",")' /run/cdi/nvidia-container-toolkit.json)" = "0,all" ]
   rc=0
   docker run --rm --device nvidia.com/gpu=all "$img" nvidia-smi -L || rc=1
   sudo podman run --rm --device nvidia.com/gpu=all "$img" nvidia-smi -L || rc=$((rc | 2))
   docker image rm -f "$img" >/dev/null 2>&1 || true
   sudo podman image rm -f "$img" >/dev/null 2>&1 || true
   echo "containers rc=$rc"   # 0 = both OK, 1 = docker failed, 2 = podman failed
   exit "$rc"
   ```

   If only docker failed (`rc=1`), dockerd may have missed the recreated
   `/run/cdi`. Restart docker once (`AGENT_BUS_ANNOUNCED=1`, already in
   the post) and run the script again.
   Traps: `start` is a no-op on this active oneshot; it must be
   `restart`. Rootless podman is out of scope. One SSH call per check
   (p510-style SSH limits don't apply, but keep it batched).

6. Comment the results on #2853 and close it, then post the outcome on
   the bus.

## Tests

- Step 2: every eval matches, the parse succeeds, and
  `just test-host razer` exits 0.
- Step 4: the deploy has no failed generator unit.
- Step 5: the script exits 0: `Result=success`, no `SIGSEGV` in that
  invocation, devices `0,all`, and both `nvidia-smi -L` print the GPU.
- Not tested on the host (reading only): failure path, driver-bump switch,
  boot path. As the spec notes, `restartIfChanged = false` also defers
  toolkit-only or `mounts` changes until a boot or a manual restart.

## Rollback

Fastest: on razer, switch to the previous generation
(`sudo nixos-rebuild switch --rollback`), after a bus post and with
`AGENT_BUS_ANNOUNCED=1`. Permanent: a revert PR from a worktree branch
(never a commit on `main`), merged, then `git pull --ff-only` in
`~/.config/nixos` and `just deploy-via-p620 razer` (announced). Nothing
outside `/run/cdi` holds state.

## Review notes

The draft was reviewed by Codex (gpt-6.1-sol) and agy (model not reported),
read-only. Fixed: step 5 now fails loudly (no `grep -c` exit-1 trap, the
journal scoped to that invocation, a script run via `ssh bash -s`), the PR
uses `Refs`, rollback goes through a PR, images are removed, the parse gate
replaces `check-syntax`, and p620 is named as the build host. Advice only,
not approval.
