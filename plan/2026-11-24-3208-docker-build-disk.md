---
status: approved
issue: 3208
spec: spec/2026-11-24-3208-docker-build-disk.md
coders:
  1: codex # small but tricky: new options, a oneshot unit with Requisite, a lock, and conditional daemon settings
  2: coder # a few lines in k3d.nix
  3: coder # host paths, the mount move and comments across two p620 files
reviewers:
  - codex # a fresh session reads the diff and the step 5-7 runbook against this plan
  - agy # independent read, focused on mounts, unit dependencies and the runbook commands
---

# Plan: p620 Docker images and build cache on the build disk, cleaned daily

## Decisions carried over

- **Paths:** containerd's root moves to `/mnt/build/containerd` and Docker's `data-root` to `/mnt/build/docker`.
  The volumes bind keeps `device = "/home/docker-volumes"` and moves to `/mnt/build/docker/volumes`. k3d's
  storage (`/mnt/code/k3d/storage`) doesn't change.
- **Mounts:** Docker requires `/mnt/build` and `/mnt/build/docker/volumes`; containerd requires `/mnt/build`.
  No tmpfiles rule for any Docker or containerd path. `fileSystems."/mnt/img_pool"` stays until the old store
  is deleted.
- **Migration:** copy with everything stopped, then rewrite `/mnt/img_pool/docker` to `/mnt/build/docker` in the
  copy's `config.v2.json` and `hostconfig.json` only. The old store is never modified. Rollback goes to the old
  store; recreating the cluster needs the owner's OK and a volumes backup.
- **Daily `docker-gc` at 04:00**, no catch-up and no random delay. It prunes build cache unused for 24 h, then
  cache down to 200 GB free, then dangling images. It never runs container, volume or system prune.
  `Requisite=docker.service`.
- **BuildKit `builder.gc`** with a `minFreeSpace` policy, best-effort between nights.
- **`k3d-image-gc`** stays weekly (Sat 04:00), runs after `docker-gc`, and its host image prune becomes `-af`.
- **Owner OKs:** before recreating the cluster (step 5.9) and before deleting the old store (step 7).
- **Deviation from spec 2.6 ("switch with Docker held down"):** the switch may start containerd, Docker and the
  bootstrap itself. A runtime mask would make those starts fail during activation, and `just p620` can roll back
  on a failed unit. Instead the copy, the rewrite and their checks finish before the switch (5.4–5.5), and the
  generated mount requirements order the bind before Docker. Step 5.6 verifies the result right after the switch.

## Steps

1. **`modules/containers/docker.nix`** (codex).

   **Options:** after the `dataRoot` option (ends line 44), add:

   ```nix
   gc = {
     enable = mkEnableOption …;
     dates = mkOption { type = types.str; default = "04:00"; };
     minFreeSpace = mkOption { type = types.nullOr types.str; default = null; example = "200GB"; };
   };
   ```

   **Config,** inside `config = mkIf cfg.enable`:
   - `daemon.settings` (line 78): when `cfg.gc.enable && cfg.gc.minFreeSpace != null`, merge with `//`, as
     `data-root` is:

     ```nix
     builder.gc = { enabled = true; policy = [ { minFreeSpace = cfg.gc.minFreeSpace; all = true; } ]; };
     ```

   - `systemd.services.docker-gc = mkIf cfg.gc.enable`:
     - `requisite = [ "docker.service" ]; after = [ "docker.service" ];`
     - `path = [ config.virtualisation.docker.package pkgs.util-linux ];`
     - `environment.DOCKER_CONFIG = "/tmp/docker-config";`
     - `serviceConfig = { Type = "oneshot"; NoNewPrivileges = true; ProtectHome = true;
       ProtectSystem = "strict"; PrivateTmp = true; };`
     - A comment explains why it runs as root and not `DynamicUser`: the Docker socket, and the `docker` group is
       root-equivalent. `k3d-image-gc` has the same exception.
   - **Script:** `set -eu`, then `exec 9>/run/docker-prune.lock; flock 9`, shared with `k3d-image-gc`. Then:
     1. `docker builder prune -af --filter until=24h`;
     2. if `minFreeSpace` is set, `docker builder prune -af --min-free-space ${lib.escapeShellArg cfg.gc.minFreeSpace}`;
     3. `docker image prune -f`;
     4. `docker system df`.
   - `systemd.timers.docker-gc = mkIf cfg.gc.enable`: `wantedBy = [ "timers.target" ];
     timerConfig = { OnCalendar = cfg.gc.dates; Persistent = false; };`.

   **Verify:** `just check-syntax`. For razer and p510, `nix eval .#nixosConfigurations.<host>.config.systemd.services
   --apply 'x: x ? docker-gc'` is `false`, and the same holds for `systemd.timers`.

   **Traps:**
   - Never `container`, `volume` or `system prune`; stopped k3d nodes would lose their state.
   - `/run` stays writable under `ProtectSystem=strict`, so the socket and the lock both work.
   - No `with lib` beyond the file's own `inherit`. Keep `restartTriggers`.

2. **`modules/containers/k3d.nix`** (coder).
   - Line 1256: `after = [ "docker.service" "k3d-cluster-bootstrap.service" "docker-gc.service" ];`.
   - At the start of the script, take the same lock: `exec 9>/run/docker-prune.lock; flock 9`. Add
     `pkgs.util-linux` to its `path`.
   - Line 1288: `docker image prune -af | tail -1`. Update the comment above it: unused tagged images go weekly,
     and images a container uses (stopped ones too) stay.

   **Verify:** `just check-syntax`.

   **Traps:** leave `volume prune` and `builder prune -f` as they are. p510 has no k3d (#1747).

3. **p620 host** (coder).
   - `hosts/p620/configuration.nix`:
     - Inside the existing `modules.containers.docker = { … };` block (lines 338–345), with no separate
       dotted line: `dataRoot = "/mnt/build/docker";` and `gc = { enable = true; minFreeSpace = "200GB"; };`.
     - `virtualisation.containerd.settings.root = "/mnt/build/containerd";` (line 347).
     - `docker.unitConfig.RequiresMountsFor = [ "/mnt/build" "/mnt/build/docker/volumes" ];` (lines 542–545).
     - `containerd.unitConfig.RequiresMountsFor = [ "/mnt/build" ];` (line 546).
     - Update the comments at lines 298–301 and 342–346: the store is on the Lexar (#3208).
   - `hosts/p620/nixos/hardware-configuration.nix`:
     - Rename `fileSystems."/mnt/img_pool/docker/volumes"` (line 111) to `fileSystems."/mnt/build/docker/volumes"`.
       Keep the same `device`, and add `"x-systemd.requires-mounts-for=/mnt/build"`.
     - Update the comments at lines 96–97 and 108–110: the Micron holds only the old store until it is deleted.
       Don't name `/dev/sdX`.

   **Verify:** `just check-syntax`, then `nix eval` on p620 of:
   - `virtualisation.docker.daemon.settings`;
   - `virtualisation.containerd.settings.root`;
   - `fileSystems."/mnt/build/docker/volumes"` (`device`, `fsType`, `options`);
   - `systemd.services.{docker,containerd}.unitConfig.RequiresMountsFor`;
   - `systemd.services.docker-gc` (`requisite`, `after`, `script`);
   - `systemd.timers.docker-gc.timerConfig`.

   **Traps:** the dotted-path rule (comment at lines 329–335): mixing a block and a dotted line for the same
   parent breaks CI's older Nix. No tmpfiles rule under `/mnt/build` for Docker paths.

4. **Build, validate, PR** (lead).
   - `just test-host p620` and `just test-host razer`.
   - Find the generated `daemon.json` from the built p620 unit: `ExecStart`'s `--config-file`, in
     `systemctl cat` of the result's `docker.service`. Run that build's
     `dockerd --validate --config-file <it>`.
   - Check `DOCKER_CONFIG=$(mktemp -d) <built docker>/bin/docker builder prune --help` lists `--min-free-space`.
   - Commit steps 1–3, and open the PR linking intent, spec and plan, with the root exception noted.
   - Reviews: the lead's own, plus a fresh Codex session and agy, given the diff and steps 5–7 of this plan.
     Merge on green.

5. **Migration** (lead). Announce on the bus first: a window of about 25 minutes, including the volumes
   backup. Run it from `main` in `~/.config/nixos`. Every command runs with `sudo`. Every check must pass before
   going on: if one fails, stop at that point, or go to 5.8 once 5.6 has run.
   1. **Record:**
      - `git pull --ff-only`, then `just test-host p620`, so the switch builds nothing.
      - Note the current generation number: `readlink /nix/var/nix/profiles/system`.
      - Save `docker inspect` of every container and `docker volume ls`, `docker images` and
        `kubectl get nodes,pods,pvc -A` to the scratchpad.
      - Create the sentinel ConfigMap `migration-3208` in `default`.
   2. **Stop:**

      ```bash
      systemctl stop k3d-image-gc.timer docker-gc.timer k3d-cluster-bootstrap 2>/dev/null
      docker ps -q | xargs -r docker stop -t 60
      test -z "$(docker ps -q)" && test -z "$(ctr -n moby tasks ls -q)"
      systemctl stop docker.socket docker containerd
      ! pgrep -f containerd-shim-runc
      ```

      If a node hangs on shutdown (the NFS case in `docker.nix`), stop and ask the owner.
   3. **Disks and unbind:**
      - `findmnt -M /mnt/build` shows the Lexar (`06f7240e-…`), `findmnt -M /mnt/img_pool` shows the Micron
        (`82b43c59-…`), and `findmnt -M /home` is mounted.
      - `/mnt/build` has more free space than `du -xs /mnt/img_pool` plus 150 GB.
      - `/mnt/build/containerd` and `/mnt/build/docker` don't exist yet.
      - `umount /mnt/img_pool/docker/volumes`, then check that `findmnt -M /mnt/img_pool/docker/volumes` prints
        nothing.
   4. **Back up and copy:**

      ```bash
      rsync -aHAX --numeric-ids /home/docker-volumes/ /mnt/img_pool/backup-3208-volumes/   # ~105 GB
      rsync -aHAX --numeric-ids /mnt/img_pool/containerd/ /mnt/build/containerd/
      rsync -aHAX --numeric-ids --exclude=/volumes/ /mnt/img_pool/docker/ /mnt/build/docker/
      install -d /mnt/build/docker/volumes && chmod --reference=/mnt/img_pool/docker/volumes /mnt/build/docker/volumes
      ```

      - Each `rsync` must exit 0.
      - Compare `find | wc -l` of each source and copy, with the same exclusion. Small `du` differences between
        filesystems are fine.
      - The volumes backup goes on the Micron because `/home` has only about 150 GB free.
   5. **Rewrite:**
      - Count the occurrences first, with `grep -o /mnt/img_pool/docker … | wc -l`.
      - Run `sed -i 's#/mnt/img_pool/docker/#/mnt/build/docker/#g'` on
        `/mnt/build/docker/containers/*/{config.v2.json,hostconfig.json}`.
      - Check that `jq empty` passes on each file and that `grep -rl /mnt/img_pool /mnt/build/docker/containers`
        prints nothing.
      - Diff one file against its old copy: only path fields may differ.
   6. **Switch:** `AGENT_BUS_ANNOUNCED=1 just p620`.
      - The switch may start containerd, Docker and the bootstrap itself (see the deviation above). Right after
        it, check that `findmnt -M /mnt/build/docker/volumes` shows `/home`'s device with root `/docker-volumes`.
      - Start whatever the switch did not, in this order: `mnt-build-docker-volumes.mount`, `containerd`,
        `docker.socket`, `docker`, `k3d-cluster-bootstrap`, then `k3d-image-gc.timer` and `docker-gc.timer`.
   7. **Check:**
      - `docker info -f '{{.DockerRootDir}}'` is `/mnt/build/docker`.
      - containerd's root, read from the file in `systemctl show -p ExecStart containerd` (`--config`), is
        `/mnt/build/containerd`, and `sudo lsof +D /mnt/build/containerd` shows containerd.
      - Container IDs, names and images, and each container's mounts (type, name, destination), match the
        record. Anonymous volumes and the `/mnt/code/k3d/storage` bind are included.
      - `docker inspect` has no `/mnt/img_pool`, and `sudo lsof +D /mnt/img_pool` shows no process, with
        exit 1 and no error text.
      - `kubectl get nodes,pods,pvc -A`: the nodes are Ready, the pods match the record, the PVCs are Bound, and
        the sentinel ConfigMap reads back.
      - `docker logs --tail 5 k3d-factory-server-0` works.
      - `systemctl cat docker containerd mnt-build-docker-volumes.mount` shows both mount requirements and
        `/home`.
   8. **Rollback**, if a check fails:
      - stop everything as in 5.2;
      - `umount /mnt/build/docker/volumes`;
      - `nixos-rebuild switch --rollback`, which goes to the generation recorded in 5.1;
      - check that `findmnt -M /mnt/img_pool/docker/volumes` shows the `/home` bind (mount it if not), and that
        Docker's root and containerd's root are the old paths;
      - start `containerd`, `docker.socket`, `docker`, `k3d-cluster-bootstrap` and the timers;
      - run the 5.7 checks against the old paths;
      - post on the bus.

      The shared volumes may hold writes from the new run; `/mnt/img_pool/backup-3208-volumes` is the
      pre-migration copy.
   9. **Recreate,** only with the owner's OK: `k3d cluster delete` removes the nodes' volumes. Only
      `/mnt/code/k3d/storage` (the PVs) and the 5.4 backup carry over.
   10. **Finish:** delete the ConfigMap and post "done" on the bus.

6. **Cleanup checks** (lead), after the switch.
   1. **Set up:**
      - `docker create --name gc-test-3208 alpine` (a stopped container), and note its image ID.
      - Build a small image as `gc-test-3208:img` twice, with a changing `ARG` and `--no-cache`, so the first
        build becomes a distinct dangling image. Note its ID.
      - Record the build cache from `docker buildx du`.
   2. **Run** `systemctl start docker-gc`, then check:
      - the dangling image ID is gone;
      - `gc-test-3208` still exists, with its original image ID;
      - the fresh build cache is still there (less than 24 h old, more than 200 GB free);
      - the journal shows three prunes and `docker system df`.
   3. **Docker down:** with Docker stopped, `systemctl start docker-gc` fails and leaves Docker down. Then start
      Docker again.
   4. **Schedule and policy:**
      - `systemctl list-timers docker-gc` shows the next 04:00;
      - `docker buildx inspect` (or the daemon's startup log) shows the GC policy;
      - a fresh `docker build` grows `/mnt/build/containerd` (`du` before and after), not `/mnt/img_pool`.
   5. **Clean up:** remove `gc-test-3208` and the test image, then post the results on #3208.

   The 24 h cutoff and the 200 GB floor are not forced in a test. Each would need a day's wait or filling the
   shared disk.

7. **Old store** (lead), after a day of normal use and with the owner's OK:
   - **Checks:**
     - `findmnt -M /mnt/img_pool` is the Micron (`82b43c59-…`);
     - `findmnt -M /mnt/img_pool/docker/volumes` prints nothing;
     - `findmnt -R /mnt/img_pool` lists no submounts;
     - `sudo lsof +D /mnt/img_pool` shows no process (exit 1, no error text).
   - **Delete:** `sudo rm -rf --one-file-system /mnt/img_pool/containerd /mnt/img_pool/docker`. Keep the
     volumes backup until the owner says otherwise.

   What to do with the Micron afterwards is a separate issue.

## Tests

| check | expected |
| --- | --- |
| `just check-syntax` | passes |
| p620 eval (step 3) | new paths, both mount requirements, `docker-gc` Requisite and lock, timer at 04:00 with `Persistent = false`, `builder.gc` policy |
| razer and p510 eval | no `docker-gc` service or timer, `daemon.settings` unchanged |
| `dockerd --validate` and the prune flag (step 4) | both pass with the built packages |
| `just test-host p620`, `razer` | builds |
| migration 5.7 | every check matches |
| cleanup (step 6) | the dangling image is gone; the stopped container, its image and fresh cache are kept; Docker stays down with Requisite |

## Rollback

- **Before step 5:** revert the PR.
- **During or after step 5, while the old store exists:** step 5.8.
- **After step 7:** no store rollback. A revert would need the store copied back by hand first, because the old
  config would otherwise start Docker on an empty `/mnt/img_pool` store.
