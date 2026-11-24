---
status: draft
issue: 3208
author: olafkfreund
---

# Intent: p620 Docker images and build cache on the build disk, cleaned daily

## Problem

On p620, Docker keeps its images and build cache in containerd's store, `/mnt/img_pool/containerd`, on the
256 GB Micron SATA SSD (`sde`). The owner builds and pulls images all day while developing, and that store had
grown to about 186 GB, 80% of the disk, before a manual prune on 2026-11-24 freed about 170 GB of unused images
and build cache. It is 24 GB now.

The only automatic cleanup is `k3d-image-gc` (`modules/containers/k3d.nix`), which p620 runs on Saturdays at
04:00. It removes only dangling images and dangling build cache, so images and cache that are no longer used but
still tagged pile up for a week or longer.

The new Lexar NVMe (`/mnt/build`, #3194) is faster than the Micron and is 1% used.

## Proposed outcome

- New image pulls, image layers and `docker build` cache on p620 land on `/mnt/build` (the Lexar NVMe), not on
  the Micron.
- Once every 24 hours, images and build cache that nothing has used for a day are removed automatically.
  Running and stopped containers, and Docker volumes in use, are never touched.
- The k3d `factory` cluster comes back after the move with its state intact.

## Affected users and systems

- p620 only: `hosts/p620/configuration.nix` (containerd root, mount requirements, GC schedule), and the cleanup
  in `modules/containers/k3d.nix` or a new module.
- The `factory` k3d cluster (3 containers) is stopped during the move.
- `/mnt/build` gets a second heavy user besides nix builds and the agents' VM workspace. The owner chose this
  after being told (2026-11-24) that it puts Docker on the same disk as nix builds.
- p510 and razer: no change. p510 does not run k3d any more (#1747).

## Constraints

- Docker volumes stay where they are (`/home/docker-volumes`, bound at `/mnt/img_pool/docker/volumes`, #3109):
  they hold the k3d cluster state.
- containerd and Docker must refuse to start when `/mnt/build` is missing, the same way they now require
  `/mnt/img_pool`, so they never start on an empty store on `/`.
- The cleanup must not use `docker system prune` or `virtualisation.docker.autoPrune`: they remove stopped
  containers, and a k3d node stopped mid-reboot would lose its state (see `k3d.nix`).
- Announce on the agent bus before the move. It stops Docker and the cluster for a few minutes.

## Open questions

1. **What moves:** only containerd's root (images, layers, build cache, and the running containers'
   filesystems), or also Docker's `data-root` (`/mnt/img_pool/docker`: container metadata and logs, a few MB)?
   Recommendation: containerd's root only.
2. **The Micron afterwards:** keep the old store there until the move is verified, then delete it. The disk is
   then empty apart from `docker/` (the data-root and the volumes bind point). Recommendation: yes, and decide
   later what the free 230 GB is used for.
3. **How hard to clean:** remove unused images and build cache older than 24 hours
   (`--filter until=24h`), or everything unused each night (which means re-pulling base images every day)?
   Recommendation: older than 24 hours, plus dangling volumes as today.
4. **When:** daily at 04:00 like the other jobs, or another time?
