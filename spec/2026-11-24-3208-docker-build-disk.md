---
status: draft
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
- The stale comment at lines 298–301 (store "on /") is fixed.

`hosts/p620/nixos/hardware-configuration.nix`: the volumes bind moves to
`fileSystems."/mnt/build/docker/volumes"` with the same `device`, plus
`x-systemd.requires-mounts-for=/mnt/build` next to the `/home` one. `fileSystems."/mnt/img_pool"` stays (it
holds the old copy until step 4 of the migration). No tmpfiles rule is added for any Docker or containerd path,
so a missing Lexar never gets an empty store built on `/`.

When the Lexar is missing, `mnt-build.mount` fails. containerd, Docker and the volumes bind refuse to start,
and so does `k3d-cluster-bootstrap`, which `Requires=docker.service`. Nix still builds on `/` (#3194, tested
2026-11-24 with a failing mount). Docker then needs only the Lexar and `/home`; the Micron is no longer on its
path.

### 2. Migration (once, in a bus-announced window, about 10 minutes)

The k3d node containers keep their writable layers in containerd's snapshots and their state in named and
anonymous volumes. Both move intact: the snapshots by copy, the volumes by not moving at all. Docker resolves a
named volume's path through the volume store when a container starts, so mount sources under the old data-root
are recomputed under the new one.

1. Build the new system first, so the window has no build.
2. Stop `k3d-cluster-bootstrap` and the three `k3d-factory-*` containers, then `docker.socket`, `docker` and
   `containerd`. `live-restore` is on, so the containers are stopped explicitly. Confirm nothing is left with
   `ctr -a /run/containerd/containerd.sock`, or that containerd is inactive.
3. Copy with `rsync -aHAX --numeric-ids`: `/mnt/img_pool/containerd/` → `/mnt/build/containerd/`, and
   `/mnt/img_pool/docker/` → `/mnt/build/docker/` excluding `volumes/` (that is the `/home` bind). Compare
   `du` and file counts.
4. Switch (`just p620`). It moves the volumes bind and starts containerd and Docker on the new paths. Then
   start `k3d-cluster-bootstrap`.
5. Check: `docker info` shows `/mnt/build/docker`, containerd's root shows `/mnt/build/containerd`,
   `docker images` lists the same images, the three nodes are up, and `kubectl get nodes` and the factory pods
   are Ready.
6. If the nodes do not start from the copy, recreate the cluster with `k3d cluster delete` and the bootstrap on
   the same volumes and storage. Delete the volumes only if the owner agrees.
7. After a day of normal use, delete `/mnt/img_pool/containerd` and the old `/mnt/img_pool/docker` (except the
   empty `volumes` mount point), with the owner's OK.

### 3. Daily cleanup: `modules/containers/docker.nix`

New options under `modules.containers.docker.gc`:

- `enable` (default false)
- `dates` (default `"04:00"`)
- `minFreeSpace` (default `null`; p620 sets `"200GB"`)

With `gc.enable`:

- **`docker-gc.service`** (oneshot, `Type=oneshot`, `After=` and `Requires=docker.service`) runs
  `docker builder prune -af --filter until=24h` (build cache not *used* for 24 hours; BuildKit filters cache by
  last use, unlike images), then `docker image prune -f` (dangling images only), then `docker system df`.
  It never runs `container prune`, `volume prune` or `system prune`. The unit takes the repo's hardening where
  it can: `NoNewPrivileges`, `ProtectHome`, `ProtectSystem=strict`, `PrivateTmp`. It needs root on the Docker
  socket rather than `DynamicUser` (the same exception `k3d-image-gc` has), and the PR documents that.
- **`docker-gc.timer`**: `OnCalendar = dates`, `Persistent = false` (no catch-up at boot),
  `RandomizedDelaySec = "10m"`.
- **Continuous floor:** `virtualisation.docker.daemon.settings.builder.gc` with `enabled = true` and the policy
  `[ { minFreeSpace = <minFreeSpace>; all = true; } ]`, set only when `minFreeSpace` is not null. BuildKit's own
  GC, not the timer, then prunes build cache whenever free space on its disk drops under 200 GB. This keeps
  Docker from starving nix builds between nightly runs. A `daemon.settings` change restarts Docker
  (`restartTriggers`), and `live-restore` keeps the containers up.

`k3d-image-gc` keeps its Saturday 04:00 schedule. Its host prune moves from `docker image prune -f` to
`docker image prune -af`, so unused tagged images are removed weekly. Images that containers use, stopped ones
included, are never removed.

Images are not size-capped. The 200 GB floor covers build cache only; an image flood larger than the free
space between Saturdays would still fill the disk. Today images are 24 GB on a 916 GB disk.

## Alternatives rejected

- **`virtualisation.docker.autoPrune`:** it runs `docker system prune`, which removes stopped containers
  (stopped k3d nodes lose their state).
- **`docker image prune -a --filter until=24h` daily:** `until` filters images by creation time, so every
  base image older than a day would go each night.
- **The timer alone, with `--min-free-space`:** it runs once a day and does not protect the disk between runs.
  With a filter it also prunes only until the free-space target is met, not everything older than 24 hours.
- **Moving only containerd's root:** leaves BuildKit metadata and container logs on the Micron, and makes
  Docker need three disks.
- **A fresh store instead of a copy:** 24 GB copies in about a minute and keeps the nodes as they are.
  Recreating stays as the fallback.
- **Putting the cleanup in `k3d.nix`:** it is a Docker concern that applies without k3d.

## Risks

- **p620, migration:** a node fails to start from the copied snapshot (e.g. an xattr or whiteout not kept).
  Mitigation: `rsync -aHAX`, the old store is kept, and the fallback is to recreate the cluster.
- **p620, disk:** nix builds, the VM workspace and Docker share the Lexar. BuildKit's floor protects against
  build-cache growth only.
- **p620, daemon restart:** `builder.gc` in `daemon.json` must parse. A bad key stops `dockerd` from starting.
  Mitigation: check the generated `daemon.json` and run `dockerd --validate --config-file` before the switch.
- **p510 and razer:** the new options default to off, and `k3d-image-gc`'s `-a` affects only hosts that enable
  it (p620).

## Verification

- `just check-syntax`; `nix eval` of p620's `virtualisation.docker.daemon.settings`,
  `virtualisation.containerd.settings.root`, `fileSystems."/mnt/build/docker/volumes"`, both units'
  `RequiresMountsFor`, and `docker-gc.timer`'s `timerConfig`; p510 and razer evaluate unchanged
  (`docker-gc` absent).
- `dockerd --validate --config-file <generated daemon.json>` succeeds.
- `just test-host p620`.
- After the switch: the five checks in migration step 5, `systemctl list-timers docker-gc`, and a manual
  `systemctl start docker-gc` whose log shows the two prunes and `docker system df`.
- A `docker build` leaves its cache under `/mnt/build/containerd` (`du` before and after).
