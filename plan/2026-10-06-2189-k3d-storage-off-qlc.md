---
status: approved
issue: 2189
spec: spec/2026-10-06-2189-k3d-storage-off-qlc.md
---

# Plan: the k3d factory databases do not share a disk with bulk data

## Approved decisions (carried from the spec)

- **Target.** `modules.containers.k3d.storageDir` becomes
  `/mnt/code/k3d/storage` (BIWIN, sustained writes, 859 GB free).
- **Method.** The module's supported recreate path: snapshot the PVs,
  delete the cluster, copy the PV directories, bootstrap, and restore the
  pre-bound PVs.
- **Guard.** Add `RequiresMountsFor = [ cfg.storageDir ]` on `docker` and
  `k3d-cluster-bootstrap`. Without the PV disk, Docker must not start
  rather than create empty PV directories.
- **Ollama models stay on `/mnt/data`.**
- **Hard ordering.** #2187 is merged and deployed first. Otherwise the
  recreate re-seeds the expired credential.

## Deviation found while planning (needs approval with this plan)

The spec's decision 2 says the k3d backups stay on `/mnt/data`. In the code,
the backup directory is derived from `storageDir`:

- `${builtins.dirOf (toString cfg.storageDir)}/backups/<name>`, at
  `k3d.nix:861` (keycloak) and `k3d.nix:945` (skillai).
- Also the `/mnt/data/k3d/backups` path in #2188.

Moving `storageDir` therefore moves the backups to `/mnt/code/k3d/backups`.
**This plan lets them follow:** one knob, and 47 MB. It copies the existing
history across in step 4. The alternative is a separate `backupDir`
option, which adds config for no gain.

## Facts the steps rely on

- **storageDir.** It is set at `hosts/p620/configuration.nix:462`.
- **Guard placement.** The module's `config` block starts at
  `k3d.nix:753`; `k3d-cluster-bootstrap` is defined at `k3d.nix:779`.
  `docker.unitConfig.RequiresMountsFor = [ "/mnt/img_pool" ]` already
  exists in `hosts/p620/configuration.nix` (#2182). List options merge.
- **PV snapshot.** It is at `/var/lib/k3d-factory/pv-snapshot.json`, and
  the bootstrap refreshes it on the reboot path. Restore is
  `k3d-pv-state restore`, triggered automatically on a fresh create when
  the snapshot exists (`k3d.nix:219-222`, `329-335`).
- **Images.** All images in use were pullable on 2026-10-06, including
  quay.io argocd, keycloak and oauth2-proxy. MinIO comes from `cgr.dev`.
- **k3d traps.** Bind mounts are fixed at container creation, which is why
  this needs a recreate. A recreate also loses the image cache.
- **Two trap memories.** Restart the server before the serverlb, and check
  serverlb's network attachment. Docker `live-restore`: stop and start
  containers, never delete their storage under them.

## Steps

1. **`modules/containers/k3d.nix`, inside `config = mkIf cfg.enable`: the
   guard.**
   Add
   `systemd.services.docker.unitConfig.RequiresMountsFor = [ cfg.storageDir ];`
   and
   `systemd.services.k3d-cluster-bootstrap.unitConfig.RequiresMountsFor = [ cfg.storageDir ];`.
   Use the second form if `k3d-cluster-bootstrap` already has a
   `unitConfig`: add the key there.
   Check: `nix eval .#nixosConfigurations.p620.config.systemd.services.docker.unitConfig.RequiresMountsFor`
   lists both `/mnt/img_pool` and the storage dir.

2. **`hosts/p620/configuration.nix:462`.** `storageDir = "/mnt/code/k3d/storage";`.
   Update the comment above it to say why: QLC `/mnt/data` stalls under
   bulk writes (Issue #2189).
   Check: `just test-host p620` builds.

3. **PR, held.** Commit
   `feat(p620): move k3d PV storage to /mnt/code (#2189)` and open a PR
   linking intent, spec and plan. Keep it a **draft** until step 4 is
   ready.
   Traps: the 04:00 auto-upgrade does a switch from main. Merging early
   would bootstrap against an empty `/mnt/code/k3d/storage` while the
   cluster still exists.

4. **Cutover (runtime, announced).**
   1. Confirm #2187 is deployed: `systemctl cat k3d-cluster-bootstrap | grep -c snapshot`
      is at least 1. Post to the bus: about 40 min of factory downtime.
   2. Re-check that every image is pullable:
      `kubectl get pods -A -o jsonpath='{..image}' | tr ' ' '\n' | sort -u | xargs -n1 docker manifest inspect`.
      Export with `ctr` any image that fails, and stop if one cannot be
      exported.
   3. Refresh the PV snapshot:
      `k3d-pv-state snapshot /var/lib/k3d-factory/pv-snapshot.json`. Then
      run `systemctl start factory-cli-creds-snapshot` and check that the
      snapshot file's mtime is now. This is a deviation added after the
      #2187 review: a recreate must seed the credential's current refresh
      token, not one the broker has already spent.
      Check that its count is 15 (current Bound PVs).
   4. Record pre-move facts for verification: database names and sizes
      (`psql -l`), PVC names, and `du -s` of each `pvc-*` directory.
   5. `k3d cluster delete factory`.
   6. Copy the PVs:
      `rsync -aHAXS --numeric-ids /mnt/data/k3d/storage/ /mnt/code/k3d/storage/`.
      Copy the backups:
      `rsync -a /mnt/data/k3d/backups/ /mnt/code/k3d/backups/`.
      Check: `rsync -n` shows no differences, and directory counts match.
   7. Mark the PR ready and merge it after CI, then `nh os switch` p620
      from main. Docker restarts because its unit changed; no cluster
      exists yet. Run `systemctl start k3d-cluster-bootstrap` and follow
      its journal.

   Check:
   - The journal shows `k3d-pv-state: restore applied 15, skipped 0`.
   - `docker inspect k3d-factory-server-0` shows
     `/mnt/code/k3d/storage -> /var/lib/rancher/k3s/storage`.

   Traps: if serverlb crash-loops, start the server first and confirm the
   lb is on the `k3d-factory` network.

5. **Verify (all must pass before step 6).**
   - All PVCs are Bound to the same `pvc-*` names as in 4.4.
   - Database list and sizes match 4.4. Keycloak realm login works.
   - `cred-sync` shows no refusals (#2187 effective).
   - A manual `postgres-backup` Job succeeds.
   - `k3d-backup-freshness` (if #2188 is deployed) reports ok, with the
     backups now under `/mnt/code`.
   - Load test: `dd if=/dev/zero of=/mnt/data/ddtest bs=1M count=20480 oflag=direct`
     while watching `kubectl get pod postgres-0`. It stays Ready, then
     delete `/mnt/data/ddtest`.

6. **Clean up the old copies.**
   `rm -rf --one-file-system /mnt/data/k3d/storage /mnt/data/k3d/backups`,
   only after step 5 passes, with a bus post.
   Check: `du -sh /mnt/data/k3d` is about 0.

## Tests

The step 1 and 2 build and eval checks, and every step 5 check.

## Rollback

- **Before step 6:** revert the PR, switch, `k3d cluster delete factory`,
  and `systemctl start k3d-cluster-bootstrap`. It recreates against
  `/mnt/data/k3d/storage`, which is untouched, and restores the same PVs.
- **After step 6:** restore `/mnt/data` from the `/mnt/code` copy first,
  then do the same.
