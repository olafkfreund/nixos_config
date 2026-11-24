---
status: draft
issue: 3208
spec: spec/2026-11-24-3208-docker-build-disk.md
coders:
  1: codex # small but tricky: new options, a oneshot unit with Requisite, and conditional daemon settings
  2: coder # a two-line change in k3d.nix
  3: coder # host paths, mount moves and comments across two p620 files
reviewers:
  - codex # second read of the diff against this plan
  - agy # independent read, focused on the migration-facing config (mounts, unit deps)
---

# Plan: p620 Docker images and build cache on the build disk, cleaned daily

## Decisions carried over

- **Paths:** containerd root → `/mnt/build/containerd`; Docker `data-root` → `/mnt/build/docker`. The volumes
  bind keeps `device = "/home/docker-volumes"` and moves to `/mnt/build/docker/volumes`. k3d storage
  (`/mnt/code/k3d/storage`) is unchanged.
- **Mounts:** docker requires `/mnt/build` and `/mnt/build/docker/volumes`; containerd requires `/mnt/build`.
  No tmpfiles rule for any Docker or containerd path. `fileSystems."/mnt/img_pool"` stays until the old store is
  deleted.
- **Migration:** copy with everything stopped. Rewrite `/mnt/img_pool/docker` to `/mnt/build/docker` in the
  copy's `config.v2.json` and `hostconfig.json` only. The old store is never modified. Rollback goes to the
  old store; recreating the cluster needs the owner's OK and a volumes backup.
- **Daily `docker-gc`, 04:00, no catch-up, no random delay:** build cache unused for 24 h, then cache down to
  200 GB free, then dangling images. Never container, volume or system prune. `Requisite=docker.service`.
- **BuildKit `builder.gc`:** `minFreeSpace` policy, best-effort between nights.
- **`k3d-image-gc`:** stays weekly (Sat 04:00), runs after `docker-gc`, and its host image prune becomes `-af`.
- **Owner OKs:** before step 9's recreate and before deleting the old store (step 8).

## Steps

1. **`modules/containers/docker.nix`** (codex). After the `dataRoot` option (line 28), add
   `gc = { enable = mkEnableOption …; dates = mkOption { type = types.str; default = "04:00"; };
   minFreeSpace = mkOption { type = types.nullOr types.str; default = null; example = "200GB"; }; }`.
   Inside `config = mkIf cfg.enable`:
   - `daemon.settings` (line 78) gets, only when `cfg.gc.enable && cfg.gc.minFreeSpace != null`,
     `builder.gc = { enabled = true; policy = [ { minFreeSpace = cfg.gc.minFreeSpace; all = true; } ]; };`,
     merged with `//` like `data-root` is.
   - `systemd.services.docker-gc = mkIf cfg.gc.enable`: `description`, `requisite = [ "docker.service" ];
     after = [ "docker.service" ];`, `path = [ config.virtualisation.docker.package ];`,
     `environment.DOCKER_CONFIG = "/tmp/docker-config";`, `serviceConfig = { Type = "oneshot";
     NoNewPrivileges = true; ProtectHome = true; ProtectSystem = "strict"; PrivateTmp = true; }`. The comment
     says why it is root and not `DynamicUser` (Docker socket; the `docker` group is root-equivalent; same as
     `k3d-image-gc`). The script, with `set -eu`, runs:
     `docker builder prune -af --filter until=24h`; when `minFreeSpace` is set,
     `docker builder prune -af --min-free-space <value>`; `docker image prune -f`; `docker system df`.
   - `systemd.timers.docker-gc = mkIf cfg.gc.enable`: `wantedBy = [ "timers.target" ];
     timerConfig = { OnCalendar = cfg.gc.dates; Persistent = false; };`.

   → **Verify:** `just check-syntax`; `nix eval .#nixosConfigurations.razer.config.systemd.services --apply
   'x: x ? docker-gc'` is `false`.
   **Traps:** never `container`, `volume` or `system prune` (stopped k3d nodes). `ProtectSystem=strict` still
   allows the socket (`/run`). No `with lib` beyond the file's own `inherit`. Keep `restartTriggers`.

2. **`modules/containers/k3d.nix`** (coder). Line 1256: `after = [ "docker.service" "k3d-cluster-bootstrap.service"
   "docker-gc.service" ];`. Line 1288: `docker image prune -af | tail -1`, and update the comment above it to say
   unused tagged images go weekly, and images a container uses (stopped ones too) stay.
   → **Verify:** `just check-syntax`.
   **Traps:** leave `volume prune` and `builder prune -f` as they are; p510 has no k3d (#1747).

3. **p620 host** (coder).
   - `hosts/p620/configuration.nix`:
     - `dataRoot = "/mnt/build/docker";` (line 344).
     - `virtualisation.containerd.settings.root = "/mnt/build/containerd";` (line 347).
     - `docker.unitConfig.RequiresMountsFor = [ "/mnt/build" "/mnt/build/docker/volumes" ];` (lines 542–545).
     - `containerd.unitConfig.RequiresMountsFor = [ "/mnt/build" ];` (line 546).
     - `modules.containers.docker.gc = { enable = true; minFreeSpace = "200GB"; };` next to the docker block.
     - Update the comments at lines 298–301 and 342–346 to say the store is on the Lexar (#3208).
   - `hosts/p620/nixos/hardware-configuration.nix`:
     - Rename `fileSystems."/mnt/img_pool/docker/volumes"` (line 111) to
       `fileSystems."/mnt/build/docker/volumes"`. Same `device`, add `"x-systemd.requires-mounts-for=/mnt/build"`.
     - Update the comments at lines 96–97 and 108–110: the Micron holds only the old store until it is deleted.
       Don't name `/dev/sdX`, since the letters move between boots.

   → **Verify:** `just check-syntax`; `nix eval` of p620's `virtualisation.docker.daemon.settings`,
   `virtualisation.containerd.settings.root`, `fileSystems."/mnt/build/docker/volumes".options`,
   `systemd.services.{docker,containerd}.unitConfig.RequiresMountsFor`, and
   `systemd.timers.docker-gc.timerConfig`.
   **Traps:** no tmpfiles rule under `/mnt/build` for Docker paths; the dotted-path style rule in
   `configuration.nix` (comment at lines 329–335).

4. **Build and validate** (lead). `just test-host p620`, `just test-host razer`. Run
   `dockerd --validate --config-file` on p620's generated `daemon.json` (from the built toplevel's
   `etc/docker/daemon.json`). Commit steps 1–3 with the plan, open the PR linking intent, spec and plan, and
   run the Codex and agy reviews on the diff. Merge on green.

5. **Migration** (lead), in a bus-announced window of about 15 minutes, from `main` in `~/.config/nixos`:
   1. **Record:** `git pull --ff-only` and `just test-host p620`, so the switch builds nothing. Save
      `docker inspect` of every container, `docker volume ls`, `docker images` and
      `kubectl get nodes,pods,pvc -A`. Create the sentinel ConfigMap `migration-3208` in `default`.
   2. **Stop:**

      ```bash
      systemctl stop k3d-image-gc.timer k3d-cluster-bootstrap
      docker stop $(docker ps -q)
      ctr -n moby tasks ls      # must be empty
      systemctl stop docker.socket docker containerd
      pgrep -a containerd-shim  # must print nothing
      ```

      Stop and restart the services if anything is left.
   3. **Unbind:** `umount /mnt/img_pool/docker/volumes`, then check `findmnt /mnt/img_pool/docker/volumes`
      prints nothing.
   4. **Copy:**

      ```bash
      rsync -aHAX --numeric-ids /mnt/img_pool/containerd/ /mnt/build/containerd/
      rsync -aHAX --numeric-ids --exclude=/volumes/ /mnt/img_pool/docker/ /mnt/build/docker/
      install -d -m 0701 /mnt/build/docker/volumes
      ```

      Then compare `du -s` and `find | wc -l` of source and copy. For the volumes mount point, copy the old
      one's mode with `stat`.
   5. **Rewrite:** `sed -i 's#/mnt/img_pool/docker#/mnt/build/docker#g'` on
      `/mnt/build/docker/containers/*/{config.v2.json,hostconfig.json}`. Check `jq empty` on each, and that
      `grep -rl /mnt/img_pool /mnt/build/docker/containers` prints nothing.
   6. **Switch:** `just p620`. Then make sure everything runs in this order, starting whatever the switch did
      not:
      - `mnt-build-docker-volumes.mount`, then check `findmnt /mnt/build/docker/volumes` shows
        `/home/docker-volumes`;
      - `containerd`, `docker.socket`, `docker`;
      - `k3d-cluster-bootstrap`;
      - `k3d-image-gc.timer`.
   7. **Check:**
      - `docker info -f '{{.DockerRootDir}}'` is `/mnt/build/docker`;
      - `ctr plugins ls -d` (or `containerd config dump`) shows root `/mnt/build/containerd`;
      - container IDs, names, images and volume names match the record;
      - `docker inspect` has no `/mnt/img_pool`, and `lsof +D /mnt/img_pool` is empty;
      - `kubectl get nodes,pods -A` is Ready, and the ConfigMap reads back;
      - `docker logs --tail 5 k3d-factory-server-0` works.
   8. **Rollback** if a check fails:
      - stop as in 5.2;
      - `sudo nixos-rebuild switch --rollback`;
      - remount the old bind with `mount /mnt/img_pool/docker/volumes`;
      - start everything as in 5.6;
      - post on the bus and stop the migration.
   9. **Recreate**, only with the owner's OK: back up `/home/docker-volumes` first. `k3d cluster delete`
      removes the nodes' volumes, and only `/mnt/code/k3d/storage` carries over.
   10. Delete the ConfigMap, start `docker-gc.timer` if it isn't running, and post "done".

6. **Cleanup checks** (lead), after the switch:
   - Make a stopped container (`docker create --name gc-test-3208 alpine`), a dangling image (build an image,
     then rebuild under the same tag), and some build cache.
   - `systemctl start docker-gc`. The dangling image is gone, while `gc-test-3208` and the alpine image remain.
     The journal shows the three prunes and `docker system df`.
   - `systemctl list-timers docker-gc` shows the next 04:00. `docker buildx inspect` shows the GC policy.
   - A `docker build` grows `/mnt/build/containerd` (`du` before and after), not `/mnt/img_pool`.
   - Remove `gc-test-3208`. Post the results on #3208.

7. **Old store** (lead), after a day of normal use and with the owner's OK:
   - check that `findmnt /mnt/img_pool/docker/volumes` is empty and `lsof +D /mnt/img_pool` is empty;
   - then `rm -rf --one-file-system /mnt/img_pool/containerd /mnt/img_pool/docker`.

   Whether to keep the `/mnt/img_pool` mount and what to do with the Micron is a separate issue.

## Tests

| check | expected |
| --- | --- |
| `just check-syntax` | passes |
| p620 eval (step 3) | new paths, both mount requirements, timer at 04:00 with `Persistent = false`, `builder.gc` policy |
| razer and p510 eval | no `docker-gc`, `daemon.settings` unchanged |
| `dockerd --validate` | passes on the generated file |
| `just test-host p620`, `razer` | builds |
| migration 5.7 | all checks match |
| cleanup (step 6) | dangling image gone, stopped container and its image kept, timer at 04:00 |

## Rollback

- **Before step 5:** revert the PR.
- **During or after step 5, while the old store exists:** step 5.8.
- **After step 7:** no store rollback. Revert the PR, and the next switch uses the Lexar store under the old
  paths only if it is copied back by hand.
