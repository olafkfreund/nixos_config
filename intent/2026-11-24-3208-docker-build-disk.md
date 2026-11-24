---
status: approved
issue: 3208
author: olafkfreund
---

# Intent: p620 Docker images and build cache on the build disk, cleaned daily

## Problem

On p620, Docker uses containerd's image store. Images, layers, build-cache blobs and every container's writable
filesystem are under containerd's root, `/mnt/img_pool/containerd`. Docker's own `data-root`,
`/mnt/img_pool/docker`, holds container metadata and logs and BuildKit's cache metadata (363 MB). Both are on
the 256 GB Micron SATA SSD (`/mnt/img_pool`). Docker volumes are on `/home` (`/home/docker-volumes`, bound at
`/mnt/img_pool/docker/volumes`, #3109).

The owner builds and pulls images all day while developing. The store had grown to about 186 GB (80% of the
Micron) before a manual prune on 2026-11-24 freed about 170 GB. It is 24 GB now.

The only automatic cleanup is `k3d-image-gc` (`modules/containers/k3d.nix`), run on Saturdays at 04:00. It
prunes images inside the k3d nodes (`crictl rmi --prune`), then unused volumes, then dangling images and
dangling build cache on the host. Unused but tagged images, and build cache that is no longer dangling, pile up
for a week or longer.

The new Lexar NVMe (`/mnt/build`, #3194) is faster and 1% used.

## Proposed outcome

- p620's image store, build cache and container filesystems are on `/mnt/build`, not the Micron.
- Every day, build cache not used for 24 hours and dangling images are removed. A cap keeps build cache from
  filling `/mnt/build` between runs. Running and stopped containers are never removed.
- The `factory` k3d cluster comes back after the move with its state intact.

## Affected users and systems

- p620 only: `hosts/p620/configuration.nix`, `hosts/p620/nixos/hardware-configuration.nix`, and the cleanup
  (`modules/containers/docker.nix`, or a change to `k3d-image-gc`).
- The `factory` cluster (3 containers) and Docker are down for the move, about 10 minutes.
- `/mnt/build` gets a third heavy user next to nix's build-dir and the agents' VM workspace. The owner chose
  this on 2026-11-24 after being told that it shares the disk with nix builds.
- p510 and razer: no change (p510 has no k3d since #1747).

## Constraints

- Volumes stay on `/home`. They hold the cluster state.
- The copy runs with the cluster stopped, then Docker, `docker.socket` and containerd stopped. Docker has
  `live-restore = true` (`docker.nix`), so stopping Docker alone leaves the k3d containers running and writing.
  The copy keeps hardlinks, xattrs and device nodes (overlayfs whiteouts).
- containerd and Docker refuse to start when `/mnt/build` is missing. `/mnt/build` is `nofail` so nix can still
  build on `/` when the Lexar dies. Docker and k3d stay down in that case, by design. No tmpfiles rule may create
  Docker or containerd directories under `/mnt/build`, since that would build an empty store on `/`.
- No `docker system prune` and no `virtualisation.docker.autoPrune`: they remove stopped containers, and a k3d
  node stopped mid-reboot would lose its state (`k3d.nix`).
- `docker image prune -a --filter until=24h` filters by when an image was *created*, not when it was last used.
  Almost every upstream base image is older than a day, so it would delete them all each night.
- The old store stays on the Micron until the cluster has run from the new one, then it is deleted.
- Announce on the agent bus before the move.

## Open questions

1. **What moves:** containerd's root only (Docker would then need the Micron, the Lexar and `/home`), or
   containerd's root *and* Docker's `data-root` (it needs only the Lexar and `/home`, and the Micron leaves
   Docker's path)? Recommendation: both.
2. **Copy or recreate:** copy the 24 GB store with everything stopped, or start an empty store and recreate the
   k3d node containers on the existing volumes? Recommendation: copy, and recreate only if the copy does not
   start.
3. **Daily cleanup scope:** a new daily `docker-gc` job (build cache not used for 24 h, dangling images, and a
   cache cap), with `k3d-image-gc` staying weekly for the in-node images, unused volumes and unused tagged images?
   Or run all of `k3d-image-gc` daily? Recommendation: a new daily job. Unused volumes stay weekly, giving a
   week to recover a deleted cluster's volume.
4. **Cache cap:** keep at most this much build cache, e.g. `--max-used-space 100GB`, or keep this much
   `/mnt/build` free, e.g. `--min-free-space 200GB`? Recommendation: `--min-free-space 200GB`, which protects nix
   builds directly.
5. **Time and catch-up:** daily at 04:00. If p620 was off at 04:00, run it at boot (`Persistent = true`) or
   wait for the next 04:00? Recommendation: wait, so it never runs in the middle of the workday.

## Decisions

Owner, 2026-11-24: all five recommendations. Move both containerd's root and Docker's `data-root`; copy the
store, recreating the nodes only if the copy does not start; a new daily `docker-gc` job, with `k3d-image-gc`
staying weekly; keep 200 GB of `/mnt/build` free; daily at 04:00 with no catch-up at boot.
