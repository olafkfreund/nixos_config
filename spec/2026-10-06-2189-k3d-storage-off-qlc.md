---
status: draft
issue: 2189
intent: intent/2026-10-06-2189-k3d-storage-off-qlc.md
---

# Spec: the k3d factory databases do not share a disk with bulk data

## Decisions carried from the intent approval

1. Target disk: **`/mnt/code`** (BIWIN M100 1 TB SATA, 480 MB/s sustained
   in the 2026-10-05 test, 859 GB free). Source-code I/O is light. `/home`
   is the desktop's disk, and the build SSD is hammered by CI VM installs.
2. Only the PVs move. Ollama models (mostly read) and the k3d backups
   (small) stay on `/mnt/data`.
3. Prefer a lighter swap if one is safe; otherwise use the module's
   supported path. The section below explains why the supported path wins.

## Design

### Config: two lines in two files

- `hosts/p620/configuration.nix:462`: change
  `modules.containers.k3d.storageDir` from `/mnt/data/k3d/storage` to
  `/mnt/code/k3d/storage`.
- `modules/containers/k3d.nix`: add the missing-disk guard below. It is
  generic, so every host using the module gets it.

### Missing-disk guard

Docker creates a missing bind source as an empty directory. If the PV disk
is absent at boot, the k3d node would start against empty PV directories,
and Postgres, skillai-db and Keycloak would initialise fresh, empty
databases. That is the worst outcome, worse than downtime. So the module
adds:

```nix
systemd.services.docker.unitConfig.RequiresMountsFor = [ cfg.storageDir ];
systemd.services.k3d-cluster-bootstrap.unitConfig.RequiresMountsFor = [ cfg.storageDir ];
```

`RequiresMountsFor` merges as a list with the existing
`docker.RequiresMountsFor = [ "/mnt/img_pool" ]` from #2182. Docker then
refuses to start without the PV disk, the same rule #2182 applied to
`/mnt/img_pool`.

### Migration: the module's supported recreate path

The k3d module already does this move safely, and #2156 used it (games
drive → `/mnt/data`):

1. Bootstrap snapshots the Bound PVs to
   `/var/lib/k3d-factory/pv-snapshot.json` (current, 2026-10-06 14:02).
2. `k3d cluster delete factory`.
3. Copy the PV directories `/mnt/data/k3d/storage/` →
   `/mnt/code/k3d/storage/` with `rsync -aHAXS --numeric-ids` while the
   cluster is down, so they are consistent.
4. Switch with the new `storageDir`, then start `k3d-cluster-bootstrap`. It
   creates the cluster against the new path, restores every PV as
   pre-bound (`k3d-pv-state restore`), and only then applies GitOps.
5. Verify, then delete the old PV directories on `/mnt/data`.

**Image check (done for this spec):** every image in use is pullable from
its registry. That includes the three `quay.io` images (argocd 2.13.1,
keycloak 26.1, oauth2-proxy 7.7.0); MinIO now uses `cgr.dev` (#276).
Losing the image cache on recreate therefore costs only pull time. The plan
re-runs the check immediately before the delete, because upstream can
vanish (MinIO did).

## Alternatives rejected

- **Bind-mount `/mnt/code/k3d-storage` over `/mnt/data/k3d/storage`** to
  avoid a recreate. The path would lie about where the data lives, and as
  a child of `/mnt/data` it still depends on the flaky QLC disk being
  mounted at boot.
- **Edit the k3d node container's bind in place.** Docker cannot change a
  container's mounts, and k3d's recreate of a lone server node loses the
  node identity. That is the node-password trap.
- **`/home` or the 480 GB scratch SSD.** See decision 1.
- **Move Ollama models and backups too.** See decision 2. They do not
  write in bulk under load.

## Risks

- **#2187 must land first.** Every recreate re-seeds `factory-cli-creds`.
  Until #2187 ships, a recreate seeds the expired Aug-20 credential again.
  This is a hard ordering constraint.
- **Downtime.** The `factory` and `fides` namespaces are down for the
  delete, copy, bootstrap and image pulls, roughly 20-40 min. The bus is
  announced first.
- **A PV restore failure.** The bootstrap stops before GitOps (by design),
  and the old directories are still on `/mnt/data` until verification
  passes. Rollback means setting `storageDir` back and recreating again.
- **The Docker guard affects all containers.** If `/mnt/code` is missing at
  boot, Docker does not start at all. The BIWIN tested healthy, and a loud
  outage is the intended trade.

## Verification

- `just test-host p620` builds, and the evaluated `docker` and
  `k3d-cluster-bootstrap` `RequiresMountsFor` lists contain
  `/mnt/code/k3d/storage`.
- After the bootstrap:
  - `k3d-pv-state restore applied N, skipped 0`, where N is the snapshot's
    count.
  - All PVCs are Bound to the same `pvc-<uid>` names.
  - `docker inspect k3d-factory-server-0` shows
    `/mnt/code/k3d/storage -> /var/lib/rancher/k3s/storage`.
- Data is intact: the application databases (aifactory, cfactory,
  pfactory, tfactory, myfriends, skillai) list with sizes matching
  pre-move; Keycloak realms load; a `postgres-backup` Job succeeds.
- Load test: a 20 GB `dd` to `/mnt/data` while postgres runs leaves
  postgres Ready and the I/O pressure on the PV disk unaffected.
- `/mnt/data/k3d/storage` is removed only after all of the above.
