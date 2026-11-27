---
status: approved
issue: 3259
spec: spec/2026-11-27-3259-log-review-fixes.md
coders:
  1: coder # two module-option lines, mechanical
  2: coder # two mount masks, mechanical
  3: codex # small shell logic with an exit-code edge case
  4: coder # delete one fileSystems block, trim one list, fix two comments
  5: coder # one YAML resources line in another repo
reviewers:
  - codex # independent read of the watchdog precheck and the migration order
  - agy # independent read of the data move and rollback
---

# Plan: Fix problems from the 2026-11-27 fleet log review

## Decisions (carried from the approved spec, plus one owner addition)

- **razer Wi-Fi/audio:** add `options iwlmvm power_scheme=1` and
  `options snd_hda_intel power_save=0` to razer's existing
  `boot.extraModprobeConfig`. Deviation from the spec: the spec's third line,
  `options iwlwifi power_save=0`, is dropped because razer already runs with
  it off (`modinfo`: default disable; `/sys/module/iwlwifi/parameters/power_save`
  = N on 2026-11-27). Live values today: `power_scheme` 2, HDA `power_save` 10
  (the kernel default; power-profiles-daemon does not set it).
- **razer `/boot`:** `fmask=0077`, `dmask=0077`.
- **p620 watchdog:** skip a tick (exit 0) when the token's remaining core
  quota is below 500; timer every 15 minutes instead of 5.
- **OpenObserve:** in `factory-gitops`, limit 2Gi → 4Gi, request 512Mi → 1Gi.
- **Owner addition (2026-11-27, with the spec approval: "move docker-volumes
  too"):** Docker's volumes (102 GB, the whole k3d `factory` cluster) move
  from the `/home` disk (Fanxiang NVMe, nvme1n1) onto the build disk (Lexar
  NVMe, nvme0n1, `/mnt/build`, 833 GB free), into the directory the bind
  mount covers today: `/mnt/build/docker/volumes`. The path Docker sees does
  not change, so no container config is rewritten (unlike #3208). The bind
  `fileSystems` entry goes away. `/home/docker-volumes` stays until a day of
  normal use, then is deleted with the owner's OK.
- Done without code (recorded on #3259, not in this plan's steps): p510 long
  SMART test running until about 06:30 on 28 Nov; Hyprland crash is upstream
  hyprwm/Hyprland#16591 in `--verify-config`, nothing to file; `/home` caches,
  Steam library and Podman storage deleted on the owner's word.

## Steps

1. `hosts/razer/nixos/laptop.nix:56-58`: inside the existing
   `boot.extraModprobeConfig` string, after `options i915 …`, add the two
   `options` lines above, with one comment line naming #3259.
   → verify: `nix eval .#nixosConfigurations.razer.config.boot.extraModprobeConfig`
   shows the i915 line plus the two new lines.
   Traps: do not add a second `boot.extraModprobeConfig` elsewhere (it is a
   lines option and would merge, but one place is the repo's pattern).
   Deviation (implementation): the pre-push typos hook reads `hda` as a
   misspelling of "had", so `.typos.toml` allows `hda` / `HDA`.

2. `hosts/razer/nixos/hardware-configuration.nix:27`: `options = [ "fmask=0022" "dmask=0022" ];`
   → `[ "fmask=0077" "dmask=0077" ];`.
   → verify: `nix eval '.#nixosConfigurations.razer.config.fileSystems."/boot".options'`.
   Traps: none.

3. `hosts/p620/nixos/schedule-watchdog.nix:8-13`, `:34` and `:38`:
   - In `run`, after `export GH_TOKEN` and before `exec`, add:

     ```bash
     # GitHub's rate_limit endpoint is free; a drained token skips this tick (#3259).
     left=$(gh api rate_limit --jq .resources.core.remaining 2>/dev/null) || left=
     if [[ $left =~ ^[0-9]+$ ]] && [ "$left" -lt 500 ]; then
       echo "skipping: $left GitHub API calls left"
       exit 0
     fi
     ```

     A failed check, or empty or non-numeric output (`null`), falls through
     to the script as before.
   - `:38` `OnCalendar = "*:0/5"` → `"*:0/15"`; `:34` the timer
     `description` says "every 15 minutes".
   → verify: `nix build '.#nixosConfigurations.p620.config.systemd.user.units."nixarchy-schedule-watchdog.service".unit'`;
   `shellcheck` on the generated `ExecStart` script; run a copy of that
   script with the token path and the `exec` target replaced by stubs and a
   stub `gh` on `PATH` printing `499`, `500`, `null`, or exiting 1: 499
   prints "skipping" and exits 0; the other three reach the `exec` line.
   Traps: `gh` is already on the unit's `path`; `writeShellScript` runs
   bash without `set -e`; nix `''` strings need escaping only for `${`, which
   this snippet does not use.

4. Docker volumes config, p620:
   - `hosts/p620/nixos/hardware-configuration.nix:108-121`: delete the
     comment and the `fileSystems."/mnt/build/docker/volumes"` block.
   - `hosts/p620/configuration.nix:553-558`: `docker.unitConfig.RequiresMountsFor`
     becomes `[ "/mnt/build" ]`; comment says the volumes live on the build
     disk (#3259).
   - `hosts/p620/configuration.nix:351-352`: comment: the store and its
     volumes live on the Lexar build disk (#3208, #3259).
   No other file references the bind (checked with
   `grep -rnE 'home/docker-volumes|mnt-build-docker-volumes|docker/volumes'`).
   → verify: `just test-host p620`; `nix eval` shows no
     `fileSystems."/mnt/build/docker/volumes"`.
   Traps: the PR is merged only at step 6.6, inside the maintenance window,
   after the copy is verified. Merged earlier, any deploy of `main` would
   start Docker on the empty directory under the bind.

5. `factory-gitops`, new branch `fix/observe-memory` from `origin/main`,
   `apps/observe/manifests/manifests.yaml:166-171`: `requests.memory: 1Gi`,
   `limits.memory: 4Gi`; extend the comment: 977Mi in use on 2026-11-27, 8
   OOM restarts at 2Gi (nixos_config#3259). Commit, push, PR.
   → verify after GitOps syncs: the Deployment template and the running pod
   (`kubectl --context k3d-factory -n factory get pod -l app=observe -o jsonpath='{.items[0].spec.containers[0].resources}'`)
   both show 4Gi.
   Traps: the local checkout is 93 commits behind; branch from
   `origin/main`, in a worktree.

6. Migrate the volumes and deploy p620 (Claude only; adapted from #3208's
   tested runbook). All `kubectl` calls use `--context k3d-factory`.
   0. **Before the window:** the PR has passed review but is not merged.
      `nixos-rebuild build --flake .#p620` from the branch worktree
      succeeds, so no build happens while the cluster is down.
   1. **Announce** on `#agents:freundcloud.org.uk` (k3d cluster down about
      20 minutes). No active Job:
      `kubectl get jobs -A -o json | jq '[.items[] | select((.status.active // 0) > 0)] | length'`
      is 0; otherwise wait.
   2. **Record:** `docker ps -a` (IDs, names), `docker volume ls`, each
      container's `docker inspect` mounts, `kubectl get nodes,pods -A`, the
      PVC list; write a sentinel ConfigMap.
   3. **Quiesce:** `k3d-image-gc.timer`, `k3d-cluster-bootstrap.timer`,
      `k3d-backup-freshness.timer`, `docker-gc.timer`,
      `k3d-cluster-bootstrap.service`; `docker ps -q | xargs -r docker stop`.
      While containerd runs, `ctr -n moby tasks ls` must be empty. Then
      `docker.socket`, `docker`, `containerd`; `pgrep -a containerd-shim`
      must be empty. Abort if anything is left.
   4. **Hold down and unbind:** a runtime `systemctl mask` does not work
      here: NixOS units are symlinks in `/etc/systemd/system`, which outrank
      `/run`. Instead, for each of `docker.socket`, `docker.service`,
      `containerd.service`, `k3d-cluster-bootstrap.service` and
      `mnt-build-docker-volumes.mount`, write
      `/run/systemd/system/<unit>.d/hold-3259.conf` with
      `[Unit]` / `ConditionPathExists=/run/hold-3259-release` (a path that
      does not exist), then `systemctl daemon-reload`. Drop-ins in `/run`
      apply on top of `/etc` units and vanish on reboot. Tested on
      2026-11-27 against `k3d-backup-freshness.service`: `systemctl start`
      reported `skipped, unmet condition check`. Hard check: `systemctl cat`
      of each of the five shows `hold-3259.conf`. A skipped condition does
      not fail dependents, so all five need the hold. Then
      `umount /mnt/build/docker/volumes`.
      Hard checks: `findmnt --mountpoint /mnt/build/docker/volumes` prints
      nothing; the directory is empty; `findmnt -T /mnt/build/docker/volumes -o SOURCE`
      is `/dev/nvme0n1p1`.
   5. **Copy:** `sudo rsync -aHAX --numeric-ids /home/docker-volumes/ /mnt/build/docker/volumes/`
      must exit 0; `du -s --apparent-size` and `find | wc -l` of both trees
      must match. Repeat the `findmnt -T` check.
   6. **Merge and switch:** merge the PR, update `~/.config/nixos` to
      `main` (check no `nhs` is running there first), and switch p620 from
      it with the holds in place. After the switch, `systemctl cat` of
      `docker.socket`, `docker.service`, `containerd.service` and
      `k3d-cluster-bootstrap.service` still shows `hold-3259.conf`, and none
      of them is active; a failed unit other than these means go to 9a.
   7. **Release:** `rm -r /run/systemd/system/*.d/hold-3259.conf` (only
      those files) and `systemctl daemon-reload`;
      `systemctl cat mnt-build-docker-volumes.mount` must say not found and
      `findmnt --mountpoint /mnt/build/docker/volumes` print nothing. Start
      `containerd`, `docker.socket`, `docker`. Before any container starts:
      `docker volume ls` matches step 2; every recorded mount of type
      `volume` resolves under `/mnt/build/docker/volumes`; every recorded
      `bind` mount (such as `/mnt/code/k3d/storage`, which never moved)
      still exists at its recorded path.
   8. **Start and check:** start `k3d-cluster-bootstrap` and the four
      timers. Same container IDs as recorded; nodes and pods Ready; sentinel
      reads back; `lsof +D /home/docker-volumes` empty; `findmnt -T` of a
      node's volume is nvme0n1p1.
   9. **Rollback.** The boundary is whether k3d ran on the new copy.
      Docker's store, containerd and the PVs (`/mnt/code/k3d/storage`) are
      not moved, so they always match whichever volumes copy last ran.
      - 9a. Failure before step 8 started a container: keep or reapply the
        holds, switch back to the previous generation, remove the holds,
        `systemctl start mnt-build-docker-volumes.mount`, check
        `findmnt --mountpoint` shows `/home/docker-volumes` exactly once,
        then start everything as in 7–8.
      - 9b. Failure after the cluster ran on the copy: quiesce and hold as
        in 3–4, `sudo rsync -aHAX --numeric-ids --delete /mnt/build/docker/volumes/ /home/docker-volumes/`
        (exit 0, counts match), then 9a.
      - After either, the 102 GB copy sits hidden under the bind on
        `/mnt/build`; remove it only through a private bind of `/mnt/build`
        (never through the mounted path), with the owner's OK.
   10. **Later:** after a day of normal use, with the owner's OK, delete
       `/home/docker-volumes`.
   Traps: never delete `/home/docker-volumes` in this task; bus
   announcement before quiescing anything (guard hook).

7. Deploy razer: merge `main` first, announce on the bus, then
   `just deploy-via-p620 razer`. vfat does not change `fmask`/`dmask` on
   `remount`, and the module options need a reload that drops Wi-Fi, so
   both take effect at a reboot of razer, at a time the owner picks.
   Traps: switch exit 4 on razer is cosmetic (memory `topic_razer`).

8. Follow-up on #3259: post the p510 long SMART result (due about 06:30 on
   28 Nov); a day after the deploys, report the razer kernel-log counts,
   the watchdog's failures, and whether `nixi-whatsapp`, `omarchy-voice` or
   `morning-repo` failed again.

## Tests

- `just check-syntax`; `just test-host razer`; `just test-host p620`.
- Step 3's stub-`gh` run: 499 skips, 500 / `null` / failure fall through.
- razer after deploy and reboot: `cat /sys/module/iwlmvm/parameters/power_scheme`
  = 1, `cat /sys/module/snd_hda_intel/parameters/power_save` = 0;
  `findmnt /boot -o OPTIONS` has `fmask=0077` and `dmask=0077`;
  `bootctl status 2>&1 | grep -c 'world accessible'` = 0.
  A day later `journalctl -k -g 'NMI_INTERRUPT|dma error' --since -1d` is
  empty or far below 2026-11-27's counts.
- p620: `systemctl --user list-timers nixarchy-schedule-watchdog` shows a
  15-minute cadence; `systemctl --user is-failed nixarchy-schedule-watchdog`
  says `inactive` across ticks.
- k3d: step 6.7–6.8 checks; `observe` template and pod at 4Gi; restart
  count steady for a day.

## Rollback

- Steps 1–3: revert the commit and redeploy.
- Step 4: never reverted on its own; reverting it restores the bind over
  the live copy. Use step 6.9.
- Step 5: revert the PR in `factory-gitops`.
