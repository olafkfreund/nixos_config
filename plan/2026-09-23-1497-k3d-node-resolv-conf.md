---
status: approved
issue: 1497
spec: spec/2026-09-23-1497-k3d-node-resolv-conf.md
---

# Plan: k3d image pulls survive Docker's embedded resolver (revision 2)

## Status of revision 1

Revision 1 steps 1–9 are **done**. The node-scoped resolver is in
`modules/containers/k3d.nix` (#2002), deployed on p620 on 2026-09-23. Both
bootstrap smoke checks pass, and a GC root
(`/nix/var/nix/gcroots/k3d-live-resolv`) protects the live node's old
store-path mount. Revision 1's step 10 (a naive recreate) was stopped
before `k3d cluster delete`, and this revision replaces it.

## Approved decisions (self-contained)

- **Resolver, unchanged from revision 1:** the node-scoped fix. The declared
  resolver file sits at a stable host path
  (`/var/lib/k3d-<cluster>/resolv.conf`), is rewritten in place on every
  bootstrap, and is mounted over each node's `/etc/resolv.conf` and at
  `/etc/rancher/k3s/resolv.conf`. There is a warn-only pull-path smoke check.
  Docker-wide `dns` is rejected.
- **Resolver file mode:** `chmod 0644` after the `cat`, because the
  bootstrap's `umask 077` made it 0600.
- **A recreate does not keep PVC data by itself.** local-path provisions
  fresh directories, so the old ones are orphaned (2026-06-25). Correct the
  module header, which claims otherwise.
- **PV snapshot:** on every bootstrap run against an existing cluster, write
  `/var/lib/k3d-<cluster>/pv-snapshot.json` (0600, atomic). It holds every
  Bound PV's name, labels and annotations (minus last-applied) and its spec,
  minus `claimRef.uid`/`resourceVersion` and minus status. If kubectl fails
  or finds no PVs, the old snapshot is kept.
- **PV restore:** on the create path, after the API is up and **before** the
  GitOps apply, apply the snapshot's PVs as pre-bound volumes. Any `local`
  PV whose directory is missing under `storageDir` is skipped with a WARN.
  Names, paths, sizes and reclaim policies are unchanged.
- **Stable NFS address:** pin `clusterIP: 10.43.224.175` on factory-gitops'
  `nfs-provisioner` Service. It is a no-op today and keeps the nfs PV's
  immutable `server` valid after a recreate.
- **Undeclared Secrets** (`azure-demo-creds`, `gcp-demo-creds`): a one-time
  export before the delete and a re-apply after. A follow-up issue moves them
  into agenix. The `rolehunter-*` leftovers are dropped.
- **Recreate safety:** a rehearsal on a throwaway cluster first, then
  backups, a fresh snapshot (15 entries), the delete, a full `cp -a` of
  `storageDir` while the cluster is stopped (kept a week), and the create.
  Done means every PVC is Bound to its old PV name.
- **Implementation choice:** snapshot and restore live in one small script,
  `k3d-pv-state` (`snapshot <file>` / `restore <file> <storageDir>`). The
  bootstrap calls it, and the rehearsal runs the same binary.

## Steps

### A. Code (nixos_config, `modules/containers/k3d.nix`)

1. `let` block: add `pvStateTool`, a `pkgs.writeShellApplication` named
   `k3d-pv-state` with `runtimeInputs = [ kubectl jq coreutils ]`.
   - `snapshot FILE`: run `kubectl get pv -o json` through the jq filter
     from the decisions above (Bound only), write to `FILE.tmp` under
     `umask 077`, and require `jq length > 0`. Then `mv` it to `FILE` and
     print the count. On any failure, exit non-zero without touching `FILE`.
   - `restore FILE STORAGE_DIR`: for each PV with `.spec.local.path`, map
     `/var/lib/rancher/k3s/storage/<dir>` to `STORAGE_DIR/<dir>`, and skip it
     with a WARN if that directory is missing. Wrap the rest in a
     `{kind: List}` and `kubectl apply -f -`. Print applied/skipped counts.

   → verify with `nix build` of the tool, and `k3d-pv-state snapshot /tmp/x.json`
   against the live cluster (read-only) prints 15, with `jq '.[].spec.claimRef'`
   showing no `uid`.
2. Bootstrap: add `pvStateTool` to `runtimeInputs`. Set `CREATED=0`, and
   `CREATED=1` in the create branch. After step 3 (API ready) and before step
   4, add step 3b: if `CREATED=1` and a snapshot exists, run `restore`;
   otherwise run `snapshot` (a failure only WARNs, never exits).
   *Added in implementation:* a failed **restore** exits 1 before the GitOps
   apply. The create branch touches `pv-snapshot.json.restore-pending` when a
   snapshot exists, and 3b keys on that marker rather than on `CREATED`. That
   way a `Restart=` rerun, which takes the reboot path, retries the restore
   instead of snapshotting an empty cluster and applying GitOps over new
   empty volumes. The marker is removed only after a successful restore.
3. `cat ${nodeResolvConf} > …` gets `chmod 0644 "${resolvStateFile}"` after it.
4. Header comment (lines 5–7): PV data does **not** survive a recreate by
   itself. Point to the snapshot/restore step and #1497.
5. `environment.systemPackages`: add `pvStateTool`, for the rehearsal and
   manual snapshots.
6. `just check-syntax`, `just test-host p620` → exit 0. Open the PR (links
   intent, spec and plan). Merge after CI.
7. Announce on the bus, deploy p620. The bootstrap reruns (reboot path) →
   verify that `/var/lib/k3d-factory/pv-snapshot.json` has 15 entries whose
   names equal `kubectl get pvc -A -o jsonpath='{..volumeName}'`, and that
   `resolv.conf` is 0644.

   *Found by the rehearsal (C):* two create-path bugs in revision 1's mount.
   Without these fixes the real create would have failed after the delete.
   (a) k3d refuses to create a node with a file mounted at
   `/etc/resolv.conf` while `K3D_FIX_DNS` is on, so the create runs with
   `K3D_FIX_DNS=0`. The spec had rejected that flag only as a standalone
   fix, because it leaves the node on Docker's resolver, which our mount
   replaces. (b) An `@all` node resolver mount also lands on the serverlb.
   Its nginx then can't resolve the node names and the create hangs, so that
   mount is `@server:*;agent:*`. The k3s `--resolv-conf` mount stays `@all`.

### B. GitOps (factory-gitops)

1. `apps/nfs-provisioner/manifests/manifests.yaml`: `clusterIP: 10.43.224.175`
   under the Service's `spec`. Open a PR and merge it.
   → verify that ArgoCD's `nfs-provisioner` app is Synced/Healthy, the
   Service IP is unchanged, and no nfs pod restarted.

### C. Rehearsal (throwaway cluster on p620)

1. `k3d cluster create pvrehearse --image rancher/k3s:v1.31.5-k3s1 --api-port 127.0.0.1:6551 --servers 1 --agents 0`
   with `--volume /mnt/games/k3d-rehearse/storage:/var/lib/rancher/k3s/storage@server:*`,
   using its own kubeconfig (`k3d kubeconfig get pvrehearse`). Apply a
   1-replica StatefulSet with a `volumeClaimTemplate` and a Deployment with a
   plain PVC (both local-path, busybox), and write a marker file into each
   volume.
2. `k3d-pv-state snapshot <scratch>/snap.json` → 2 entries.
    Run `k3d cluster delete pvrehearse`, recreate it with the same arguments,
    run `k3d-pv-state restore <scratch>/snap.json /mnt/games/k3d-rehearse/storage`,
    and re-apply the same manifests.
    → **pass condition:** both PVCs are Bound to the snapshot's PV names, both
    markers read back, and there is no new `pvc-*` dir under the rehearsal
    storage. On a fail: stop, revise, and don't go to D.
3. Delete the rehearsal cluster and `/mnt/games/k3d-rehearse`.

### D. The recreate (announced window, ~20–30 min downtime)

1. Bus announcement with the expected downtime, and a check that nobody is
   mid-flight on p620 or the cluster.
2. `systemctl start keycloak-realm-backup skillai-db-backup`, each with a
   fresh file checked. Export the two undeclared Secrets (under `umask 077`)
   to `/var/lib/k3d-factory/unmanaged-secrets.json`: name, namespace, type
   and data only.
3. `systemctl restart k3d-cluster-bootstrap`, then check the snapshot: 15
   entries matching the live PVC volumeNames. Also save a copy of the
   `kubectl get pvc -A` table for later comparison.
4. `k3d cluster delete factory`.
5. `cp -a /mnt/games/k3d/storage /mnt/games/k3d/storage.pre-1497`
   → verify with `diff -rq` (no output).
6. `systemctl start k3d-cluster-bootstrap` → the journal shows create,
   `restore: applied 15, skipped 0`, then the GitOps apply.
7. Wait for ArgoCD. Re-apply `unmanaged-secrets.json` once `factory`
   exists, then delete the file.
8. Tests below. Then remove the GC root `/nix/var/nix/gcroots/k3d-live-resolv`,
   post done on the bus, close #1497, and open the follow-up issue (demo
   creds into agenix; delete `storage.pre-1497` after 2026-09-30).

## Tests

1. After A7: the snapshot has 15 entries, `resolv.conf` is 0644, and the
   journal shows `DNS OK` and `node DNS OK`.
2. Rehearsal pass condition (C2).
3. After the recreate: every PVC's `volumeName` equals the D3 table and
   all are `Bound`. `ls /mnt/games/k3d/storage` shows the same 14 dirs and no
   new ones.
4. `docker inspect k3d-factory-server-0` shows both resolv mounts from
   `/var/lib/k3d-factory/resolv.conf`. Inside the node, `cat /etc/resolv.conf`
   shows 1.1.1.1/9.9.9.9 and `nslookup ghcr.io` works. After
   `docker restart k3d-factory-server-0` it still does.
5. Data: the keycloak realm login works, postgres and skillai-db list their
   tables, fides UI shows its evidence, minio lists its buckets, and the
   tfactory pod sees `projects.json` on `tfactory-data-rwx`.
6. Every ArgoCD app is Synced/Healthy. `kubectl rollout restart` of one
   ghcr.io-backed deployment reaches Running.

## Rollback

- **A and B:** revert the PRs and deploy. The live cluster is unaffected
  until D.
- **D, when a PVC is bound to a new empty volume:** scale its workload to 0,
  delete that PVC and its new PV, and remove the new `pvc-*` dir. Then
  re-apply that PV from the snapshot (it becomes pre-bound again) and let
  ArgoCD recreate the PVC.
- **D, when the whole attempt goes wrong:** `k3d cluster delete factory`,
  remove any `pvc-*` dirs that are not in the snapshot, and rerun D6.
  If a data dir itself was damaged: restore it from `storage.pre-1497`
  (with the cluster stopped), then keycloak/skillai from their backups.
- **The resolver mount itself misbehaving:** rewrite
  `/var/lib/k3d-factory/resolv.conf` in place (`cat >`), no recreate needed.
