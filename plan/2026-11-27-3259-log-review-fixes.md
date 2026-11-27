---
status: draft
issue: 3259
spec: spec/2026-11-27-3259-log-review-fixes.md
coders:
  1: coder # three module-option lines, mechanical
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

- **razer Wi-Fi/audio:** add `options iwlwifi power_save=0`,
  `options iwlmvm power_scheme=1`, `options snd_hda_intel power_save=0` to
  razer's existing `boot.extraModprobeConfig`.
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
   `boot.extraModprobeConfig` string, after `options i915 …`, add the three
   `options` lines above, with one comment line naming #3259.
   → verify: `nix eval .#nixosConfigurations.razer.config.boot.extraModprobeConfig`
   shows all four lines.
   Traps: do not add a second `boot.extraModprobeConfig` elsewhere (it is a
   lines option and would merge, but one place is the repo's pattern).

2. `hosts/razer/nixos/hardware-configuration.nix:27`: `options = [ "fmask=0022" "dmask=0022" ];`
   → `[ "fmask=0077" "dmask=0077" ];`.
   → verify: `nix eval .#nixosConfigurations.razer.config.fileSystems."/boot".options`.
   Traps: none.

3. `hosts/p620/nixos/schedule-watchdog.nix:8-13` and `:38`:
   - In `run`, after `export GH_TOKEN` and before `exec`, add:

     ```bash
     # GitHub's rate_limit endpoint is free; a drained token skips this tick (#3259).
     left=$(gh api rate_limit --jq .resources.core.remaining 2>/dev/null) || left=
     if [ -n "$left" ] && [ "$left" -lt 500 ]; then
       echo "skipping: $left GitHub API calls left"
       exit 0
     fi
     ```

     If the check itself fails (network down, empty output), fall through to
     the script as before.
   - `OnCalendar = "*:0/5"` → `"*:0/15"`; the timer `description` says
     "every 15 minutes".
   → verify: `nix build .#nixosConfigurations.p620.config.systemd.units."nixarchy-schedule-watchdog.service".unit`
   and `shellcheck` on the generated script (`ExecStart` path).
   Traps: `gh` is already on the unit's `path`; nix `''` strings need `''$`
   only for `${`, which this snippet does not use.

4. Docker volumes config, p620:
   - `hosts/p620/nixos/hardware-configuration.nix:108-121`: delete the
     comment and the `fileSystems."/mnt/build/docker/volumes"` block.
   - `hosts/p620/configuration.nix:553-558`: `docker.unitConfig.RequiresMountsFor`
     becomes `[ "/mnt/build" ]`; comment says the volumes live on the build
     disk (#3259).
   - `hosts/p620/configuration.nix:351-352`: comment: the store and its
     volumes live on the Lexar build disk (#3208, #3259).
   → verify: `just test-host p620`; `nix eval` shows no
     `fileSystems."/mnt/build/docker/volumes"`.
   Traps: Steps 4 and 6 must land together: deploying step 4 before the data
   is copied starts Docker on an empty volumes directory (the cluster would
   come up blank). The PR is not merged and p620 not deployed until step 6
   runs.

5. `factory-gitops`, new branch `fix/observe-memory` from `origin/main`,
   `apps/observe/manifests/manifests.yaml:166-171`: `requests.memory: 1Gi`,
   `limits.memory: 4Gi`; extend the comment: 977Mi in use on 2026-11-27, 8
   OOM restarts at 2Gi (nixos_config#3259). Commit, push, PR.
   → verify: `kubectl --context k3d-factory -n factory get deploy observe -o jsonpath='{.spec.template.spec.containers[0].resources}'`
   after GitOps syncs.
   Traps: the local checkout is 93 commits behind; branch from
   `origin/main`, in a worktree.

6. Migrate the volumes and deploy p620 (Claude only, after the PR passes
   review and is merged; adapted from #3208's tested runbook):
   1. Announce on `#agents:freundcloud.org.uk` (k3d cluster down about 20
      minutes); check no factory job is running
      (`kubectl get jobs -A --field-selector status.successful=0`).
   2. Record: `docker ps -a` (IDs, names), `docker volume ls`,
      `kubectl get nodes,pods -A`, PVC list; write a sentinel ConfigMap.
   3. Stop: `k3d-image-gc.timer`, `k3d-cluster-bootstrap.timer`,
      `k3d-backup-freshness.timer`, `k3d-cluster-bootstrap`, every container
      (`docker stop $(docker ps -q)`), then `docker.socket`, `docker`,
      `containerd`. `pgrep -a containerd-shim` must be empty; stop if not.
   4. `umount /mnt/build/docker/volumes`; `findmnt` must not show it, and
      the directory underneath must be empty (it is 4 KB today).
   5. `rsync -aHAX --numeric-ids /home/docker-volumes/ /mnt/build/docker/volumes/`;
      compare `du -s --apparent-size` and file counts.
   6. `nixos-rebuild switch` p620 from `main` with Docker held down (mask
      `docker.socket` for the switch and unmask after), then start
      `containerd`, `docker.socket`, `docker`, `k3d-cluster-bootstrap`, and
      the three timers.
   7. Check: same container IDs and volume names as recorded; nodes and pods
      Ready; sentinel reads back; `docker inspect` mounts resolve under
      `/mnt/build/docker/volumes` on nvme0n1 (`findmnt -T`);
      `lsof +D /home/docker-volumes` empty.
   8. Rollback if 7 fails: stop as in 3, switch back to the previous
      generation, `mount /mnt/build/docker/volumes` (the bind returns over the
      copy), start everything. `/home/docker-volumes` is untouched until the
      owner OKs deleting it.
   Traps: never delete `/home/docker-volumes` in this task; bus
   announcement before stopping anything (guard hook).

7. Deploy razer: `just deploy-via-p620 razer` (bus announcement first), then
   `sudo mount -o remount /boot` on razer. Module options apply at the next
   reboot or module reload; ask the owner when to reboot.
   Traps: switch exit 4 on razer is cosmetic (memory `topic_razer`); merge
   main first.

## Tests

- `just check-syntax`; `just test-host razer`; `just test-host p620`.
- razer after deploy and reboot: `cat /sys/module/iwlmvm/parameters/power_scheme`
  = 1, `cat /sys/module/iwlwifi/parameters/power_save` = N,
  `cat /sys/module/snd_hda_intel/parameters/power_save` = 0;
  `findmnt /boot -o OPTIONS` has `fmask=0077`; `bootctl status 2>&1 | grep -c 'world accessible'` = 0.
  A day later `journalctl -k -g 'NMI_INTERRUPT|dma error' --since -1d` is
  empty or far below 2026-11-27's counts.
- p620: `systemctl --user list-timers nixarchy-schedule-watchdog` shows a
  15-minute cadence; `systemctl --user is-failed nixarchy-schedule-watchdog`
  says `inactive` across ticks.
- k3d: step 6.7 checks; `observe` limit 4Gi; restart count steady for a day.

## Rollback

- Steps 1–4: revert the commit and redeploy.
- Step 5: revert the PR in `factory-gitops`.
- Step 6: step 6.8.
