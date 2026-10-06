---
status: approved
issue: 2189
author: olafkfreund
---

# Intent: the k3d factory databases do not share a disk with bulk data

## Problem

Every persistent volume of p620's k3d factory cluster lives on
`/mnt/data/k3d/storage` (18 GB): Postgres, skillai-db, MinIO, Keycloak and
the factory data volumes. `/mnt/data` is a QLC, DRAM-less Fanxiang S101Q,
the same model as the degraded archive drive. It also holds Ollama models,
k3d backups and other bulk data.

On 2026-10-06, a 253 GB copy onto `/mnt/data` filled the drive's cache.
I/O pressure reached 34-46% "full", postgres processes blocked on fsync,
and the 1 s liveness probe killed postgres mid-recovery nine times until
the writes drained. Any large write to `/mnt/data` (a model pull, a backup
restore, a copy) can do this again.

The same drive also missed one boot this morning (the SATA link was down
until a manual rescan), which would have left every PV path empty.

## Proposed outcome

- The k3d PVs live on a disk that sustains writes and carries no bulk
  traffic, so a large copy elsewhere cannot crash-loop the factory
  databases.
- If the PV disk is missing at boot, the cluster does not start against an
  empty directory on `/`.
- The cluster's data is unchanged after the move: same PVs, same contents,
  Postgres and the apps come back healthy.

## Affected users and systems

- p620 only: `modules.containers.k3d.storageDir` in
  `hosts/p620/configuration.nix`, the k3d node containers (bind mounts are
  fixed at container creation), and the target disk.
- Everything in the `factory` and `fides` namespaces is down during the move.

## Constraints

- k3d bind mounts do not follow config. The node containers must be
  recreated, and recreating a cluster loses its cached images. MinIO
  community images are gone upstream (401), so export the images first.
- k3s node-password and pinned k3s version traps apply on recreate.
- The stale `factory-cli-creds` seed (#2187) bites on any recreate, so fix
  #2187 first or re-seed by hand during this move.
- Announce on the agent bus. The move means cluster downtime.

## Open questions

1. Target disk: `/mnt/code` (BIWIN SATA, 480 MB/s sustained, 859 GB free,
   shared with source code), or `/home` (NVMe, ~430 GB free, shared with
   the user's home)? Or the 480 GB build-scratch SSD (fast, but CI VM
   installs hammer it)?
2. Should Ollama models and the k3d backups also leave `/mnt/data`, or only
   the PVs?
3. Can the move swap the bind source with a container recreate
   (`storageDir` change plus recreating the node), instead of a full
   cluster delete and bootstrap?

## Decisions at approval

The user approved on 2026-10-06 with the recommended answers to every open
question, as listed in the session reply.
