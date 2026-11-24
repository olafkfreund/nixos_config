---
status: approved
issue: 3208
intent: intent/2026-11-24-3208-docker-build-disk.md
---

# Spec: p620 Docker images and build cache on the build disk, cleaned daily

## Design

### 1. Paths

| what | now | after |
| --- | --- | --- |
| containerd root (images, layers, build-cache blobs, container filesystems) | `/mnt/img_pool/containerd` | `/mnt/build/containerd` |
| Docker `data-root` (container metadata, logs, BuildKit metadata) | `/mnt/img_pool/docker` | `/mnt/build/docker` |
| Docker volumes | `/home/docker-volumes`, bound at `/mnt/img_pool/docker/volumes` | same source, bound at `/mnt/build/docker/volumes` |
| k3d PV storage | `/mnt/code/k3d/storage` | unchanged |

`hosts/p620/configuration.nix`:

- `modules.containers.docker.dataRoot = "/mnt/build/docker";`
- `virtualisation.containerd.settings.root = "/mnt/build/containerd";`
- `docker.unitConfig.RequiresMountsFor = [ "/mnt/build" "/mnt/build/docker/volumes" ];`
- `containerd.unitConfig.RequiresMountsFor = [ "/mnt/build" ];`
- `modules.containers.docker.gc = { enable = true; minFreeSpace = "200GB"; };` (section 3)
- Stale comments fixed: lines 298–301 (store "on /") and 342–347 (`/mnt/img_pool`).

`hosts/p620/nixos/hardware-configuration.nix`: the volumes bind moves to
`fileSystems."/mnt/build/docker/volumes"` with the same `device`, plus
`x-systemd.requires-mounts-for=/mnt/build` next to the `/home` one. `fileSystems."/mnt/img_pool"` stays, with
its comment updated: it holds the old store until migration step 8. No tmpfiles rule is added for any Docker or
containerd path, so a missing Lexar never gets an empty store built on `/`.

When the Lexar is missing, `mnt-build.mount` fails. containerd, Docker and the volumes bind refuse to start,
and so does `k3d-cluster-bootstrap`, which `Requires=docker.service`. Nix still builds on `/` (#3194). Docker
then needs only the Lexar and `/home`; the Micron is off its path.

### 2. Migration (once, in a bus-announced window, about 15 minutes)

Docker stores absolute data-root paths in each container's `config.v2.json` (`HostsPath`, `HostnamePath`, and
named volumes' `Source`; checked on p620 2026-11-24). containerd's `meta.db` holds old OCI specs with those paths,
which Docker regenerates when it starts a container. The copy therefore gets its `config.v2.json` and
`hostconfig.json` paths rewritten. The old store is never modified, so it stays a clean rollback.

1. **Before:** build the new system. Record each container's ID, name, image and mounts (`docker inspect`), the
   volume list, `docker images`, `kubectl get nodes,pods -A` and the PVC list, and a sentinel object written
   into the cluster (a ConfigMap) to read back afterwards.
2. **Stop:** stop `k3d-image-gc.timer`, `k3d-cluster-bootstrap` and every running container (`docker ps -q`; only
   the three k3d nodes today). `live-restore` is on, so containers are stopped explicitly. While containerd still
   runs, `ctr -n moby tasks ls` must be empty. Then stop `docker.socket`, `docker` and `containerd`, and check
   that `pgrep -a containerd-shim` is empty. Stop if anything is left.
3. **Old bind off:** `umount /mnt/img_pool/docker/volumes`, then check `findmnt` no longer shows it, so no later
   step can touch the live volumes through the old path.
4. **Copy:** `rsync -aHAX --numeric-ids` `/mnt/img_pool/containerd/` → `/mnt/build/containerd/`, and
   `/mnt/img_pool/docker/` → `/mnt/build/docker/` excluding `/volumes/` (the now-empty mount point dir is
   recreated empty). Compare `du -s` and file counts.
5. **Rewrite paths in the copy:** in `/mnt/build/docker/containers/*/{config.v2.json,hostconfig.json}`, replace
   `/mnt/img_pool/docker` with `/mnt/build/docker`. Check each file still parses (`jq`) and that no file under
   `/mnt/build/docker/containers` mentions `/mnt/img_pool`.
6. **Switch and start in order:** run the switch with Docker held down. Then start
   `mnt-build-docker-volumes.mount` (check `findmnt` shows `/home/docker-volumes` there), then `containerd`,
   `docker.socket`, `docker`, and `k3d-cluster-bootstrap`, then `k3d-image-gc.timer`.
7. **Check:** `docker info` shows `/mnt/build/docker`; containerd's root is `/mnt/build/containerd`
   (`ctr` plugin info); `docker images` and the containers' IDs and volume names match the record; `docker
   inspect` shows no `/mnt/img_pool` path and `lsof +D /mnt/img_pool` is empty; the nodes and pods are Ready and
   the sentinel ConfigMap reads back; `docker logs` works on a node.
8. **Rollback, if step 7 fails:** stop the containers and daemons as in step 2, switch back to the previous
   generation, mount the old bind again (`mount /mnt/img_pool/docker/volumes`), and start everything. The old
   store is untouched.
9. **Recreate, only with the owner's OK and as a last resort:** `k3d cluster delete` removes the nodes' Docker
   volumes. New nodes get fresh anonymous volumes, and only `/mnt/code/k3d/storage` (the PVs) carries over. Back
   up `/home/docker-volumes` first.
10. **Old store:** after a day of normal use, check that `/mnt/img_pool/docker/volumes` is not a mount point and
    nothing has `/mnt/img_pool` open. Then, with the owner's OK, delete `/mnt/img_pool/containerd` and
    `/mnt/img_pool/docker` using `rm --one-file-system`.

### 3. Daily cleanup: `modules/containers/docker.nix`

New options under `modules.containers.docker.gc`:

- `enable` (default false)
- `dates` (default `"04:00"`)
- `minFreeSpace` (default `null`; p620 sets `"200GB"`)

With `gc.enable`:

- **`docker-gc.service`** (oneshot) has `Requisite=` and `After=docker.service`, so it never starts a stopped
  Docker. `path` gets the Docker package, and `DOCKER_CONFIG` points into its private `/tmp`. In order it runs:
  1. `docker builder prune -af --filter until=24h`: build cache not used for 24 hours.
  2. When `minFreeSpace` is set, `docker builder prune -af --min-free-space <minFreeSpace>`: prunes newer cache
     too, until that much is free again.
  3. `docker image prune -f`: dangling images only.
  4. `docker system df`.

  It never runs `container prune`, `volume prune` or `system prune`. Hardening: `NoNewPrivileges`,
  `ProtectHome`, `ProtectSystem=strict`, `PrivateTmp`. It runs as root for the Docker socket, the same
  exception as `k3d-image-gc`. The `docker` group would be root-equivalent anyway; the PR documents this.
- **`docker-gc.timer`**: `wantedBy = [ "timers.target" ]`, `OnCalendar = dates`, `Persistent = false` (no
  catch-up at boot), and no random delay, so it runs at 04:00 as decided.
- **Between nightly runs:** with `minFreeSpace` set, `virtualisation.docker.daemon.settings.builder.gc` is
  `enabled = true` with the policy `[ { minFreeSpace = <minFreeSpace>; all = true; } ]`. BuildKit runs this GC
  around its own activity, after builds. That covers a build session filling the disk, but it is best-effort: it
  does not react to nix builds or VM images using space, and it can only free cache that is not in use. The
  nightly step 2 is the firm floor. A `daemon.settings` change restarts Docker (`restartTriggers`), which
  `live-restore` makes safe for this compatible change only, not for the data-root move.

`k3d-image-gc` keeps its Saturday 04:00 schedule. It is ordered `after = [ "docker-gc.service" ]` so the two
never prune at once. Its host image prune becomes `docker image prune -af`, so unused tagged images go weekly.
Images that a container uses, stopped ones included, stay. Its `docker builder prune -f` (dangling cache) stays.

Images are not size-capped. The floor covers build cache only. Today images are 24 GB on a 916 GB disk.

## Alternatives rejected

- **`virtualisation.docker.autoPrune`:** it runs `docker system prune`, which removes stopped containers
  (stopped k3d nodes lose their state).
- **`docker image prune -a --filter until=24h` daily:** `until` filters images by creation time, so every
  unused base image older than a day would be re-pulled after each night.
- **BuildKit GC alone for the floor:** it runs only around build activity.
- **Keeping the old paths and binding the Lexar there:** no metadata rewrite, but `/mnt/img_pool` would name a
  disk it no longer is, forever.
- **Moving only containerd's root:** leaves BuildKit metadata and container logs on the Micron, and makes
  Docker need three disks.
- **A fresh store instead of a copy:** loses the nodes' writable layers and needs a cluster recreate.
- **Putting the cleanup in `k3d.nix`:** it is a Docker concern that applies without k3d.

## Risks

- **p620, migration:** a node fails to start from the copy (an xattr, a whiteout, or a path the rewrite
  missed). Mitigation: `rsync -aHAX`, the step 5 and 7 checks, and the step 8 rollback to the untouched old store.
- **p620, data loss:** the only destructive steps are 9 and 10, and both need the owner's OK. Step 3 removes
  the old bind before any copy, so `/home/docker-volumes` is never reachable under the old path.
- **p620, disk:** nix builds, the VM workspace and Docker share the Lexar. The floor is nightly plus
  best-effort BuildKit GC, and covers build cache only.
- **p620, daemon config:** a bad `builder.gc` key stops `dockerd` from starting. Mitigation:
  `dockerd --validate --config-file` on the generated file before the switch.
- **p510 and razer:** the new options default to off, and `k3d-image-gc`'s `-a` affects only hosts that enable
  it (p620 only).

## Verification

- `just check-syntax`. `nix eval` on p620 of `virtualisation.docker.daemon.settings`,
  `virtualisation.containerd.settings.root`, `fileSystems."/mnt/build/docker/volumes"`, both units'
  `RequiresMountsFor`, and `docker-gc`'s service and timer. p510 and razer have no `docker-gc`.
- `dockerd --validate --config-file <generated daemon.json>`.
- `just test-host p620`.
- After the switch: the migration step 7 checks; `systemctl cat` of the volumes mount, `docker` and `containerd`
  shows both mount requirements; `docker buildx inspect` shows the GC policy.
- Cleanup: create a stopped test container, a dangling image and some build cache. Run `systemctl start
  docker-gc`. The dangling image is gone, the stopped container and its image remain, and the log shows the
  prunes and `docker system df`. `systemctl list-timers docker-gc` shows 04:00. Remove the test container.
- A `docker build` grows `/mnt/build/containerd` (`du` before and after), not `/mnt/img_pool`.
