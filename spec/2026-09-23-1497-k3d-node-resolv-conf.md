---
status: approved
issue: 1497
intent: intent/2026-09-23-1497-k3d-node-resolv-conf.md
---

# Spec: k3d image pulls survive Docker's embedded resolver

Decisions from the intent approval: declaring the resolver is enough, and we
don't block on the exact root cause (open question 2). This spec settles the
width of the fix (open question 1): **node-scoped, not Docker-wide.** The
evidence is below.

> **Revision 2 (2026-09-23), after the design was implemented and deployed.**
> Design steps 1–4 are live on p620 (#2002). The recreate that makes them
> take effect was stopped before `k3d cluster delete`, because this spec
> claimed that PVCs survive a recreate. They do not. This revision replaces
> the rollout section with a recreate that keeps the cluster's state, and
> adds one fix to the deployed code (the resolver file's mode). Design steps
> 1–4 are otherwise unchanged.

## What the spec work found

- **A container restart undoes a hand repair.** `k3d-factory-server-0` was
  created 2026-08-20 and never recreated, but it was restarted 2026-09-22
  21:56. The 2026-09-18 hand edit is gone: `/etc/resolv.conf` is
  Docker-generated again (`nameserver 172.18.0.1`), and only the
  `/etc/resolv.conf.docker-bak` from that repair is left. Docker regenerates
  the file whenever the container starts. The file's own header says
  otherwise, but that is not what happened here.
- **k3d rewrites Docker's DNS NAT rules on every node start.** k3d v5.7.4's
  `/bin/k3d-entrypoint-dns.sh` runs `iptables-save | sed | iptables-restore`
  in the node netns to reroute `127.0.0.11` to the gateway `172.18.0.1`.
  That was written for Docker before 29. In Docker 29 the embedded resolver
  is *already* on the gateway, so k3d is editing rules that Docker also
  owns. And dockerd runs with `live-restore = true`
  (`modules/containers/docker.nix`), so a dockerd restart re-plumbs the
  containers' resolver while they keep running. Two owners of the same NAT
  rules is a plausible source of the intermittent `connection refused` on
  `172.18.0.1:53`. The journal from the 2026-09-18 incident has rotated, so
  this is not proven, and per the intent it does not need to be.
- **The existing k3s resolv.conf mount is a `/nix/store` path**
  (`/nix/store/ln8j…-k3d-node-resolv.conf`). It is alive only because its
  content has not changed. If `resolvers` changes, the old path is
  garbage-collected, and the Docker bind mount dies with it (the same trap
  as Docker HostConfig freezing store paths).

## Design

Everything is in `modules/containers/k3d.nix`.

1. **Stable host path for the resolver file.** A `tmpfiles` directory
   `/var/lib/k3d-<clusterName>/`. The bootstrap writes `nodeResolvConf`'s
   content to `/var/lib/k3d-<clusterName>/resolv.conf` with
   `cat … > file`, **not** `install`/`cp`, so the inode stays the same and a
   running node's bind mount sees updates. It runs on every bootstrap,
   before the create/start branch.
2. **Mount that file over the node's `/etc/resolv.conf`** at cluster create:

   ```sh
   --volume "$RESOLV:/etc/resolv.conf@all:*"
   --volume "$RESOLV:/etc/rancher/k3s/resolv.conf@all:*"   # moved off the store path
   ```

   containerd then resolves ghcr.io through `1.1.1.1`/`9.9.9.9` directly and
   never touches Docker's embedded resolver or k3d's rewritten NAT rules
   (those rules match only `-d 172.18.0.1`). k3d's DNS-fix script rewrites
   the file only if it contains `127.0.0.11` (`grep -q`), and ours does not,
   so it leaves the mount alone.
   Nothing on the node needs Docker DNS for container names: the cluster is
   one server plus serverlb, with no k3d-managed registry.
3. **Pull-path smoke check** next to the pod DNS check (`k3d.nix:396`):
   `docker exec k3d-<cluster>-server-0 nslookup ghcr.io`. Like the existing
   check, it only warns and never fails the unit, for the same
   Restart-loop reason. The warning names #1497 and says that pods in
   `ImagePullBackOff` need deleting after a repair.
4. **Option description and comments**: `resolvers` now governs both files.
   The `nodeResolvConf` comment gains the k3d-entrypoint finding in two or
   three lines.

5. **Resolver file mode.** The bootstrap runs under `umask 077` (for the
   kubeconfig), so step 1 created the file 0600. Add `chmod 0644` after the
   `cat`, which keeps the inode, so it matches the 0444 store file it replaces.
   It has already been fixed by hand on p620.

### What a recreate loses (found in review, 2026-09-23)

`storageDir` being bind-mounted does **not** carry PVC data across a
recreate. `local-path` provisions a fresh `pvc-<new-uid>_<ns>_<name>`
directory for each new PVC. The old directories stay on disk, but nothing
attaches them: this is how the keycloak realm was lost on 2026-06-25. The
module's header comment ("PVCs survive cluster recreation") is wrong in the
same way and gets corrected.

What exists only in the running cluster:

| State | Where | After a naive recreate |
| ----- | ----- | ---------------------- |
| 14 `local-path` PVs (16 GB: postgres, skillai-db, fides-db, minio, keycloak, …) | `storageDir`, one dir per PVC, no orphans today | empty new volumes |
| 1 `nfs` PV (`tfactory-data-rwx`: TFactory projects, findings, profiles) | an export inside `nfs-provisioner-backing`, reached via Service ClusterIP `10.43.224.175` | new export. The old PV's `nfs.server` is immutable and the Service gets a random new IP |
| `azure-demo-creds`, `gcp-demo-creds` Secrets | declared nowhere (not agenix, not factory-gitops) | gone |
| ArgoCD admin password, kyverno/keda certs | generated in-cluster | regenerated. This is acceptable. |

Everything else is re-seeded: every other Secret comes from agenix via the
bootstrap (`minio-kms` included), and all workloads come from factory-gitops.
Tailscale sidecars keep no state Secrets. The k3s image
(`rancher/k3s:v1.31.5-k3s1`) matches the running node, so a recreate is not
also an upgrade. The `rolehunter-*` Secrets are leftovers of #1402 and are
dropped.

### Keeping it: PV snapshot + pre-bound restore (module)

- **Step 6: snapshot.** On every bootstrap run that finds the cluster already
   existing, write `/var/lib/k3d-<cluster>/pv-snapshot.json`, 0600, atomically
   (temp file + `mv`). It holds every `Bound` PV with its name, annotations
   and spec, with `claimRef.uid`/`resourceVersion` and `status` stripped. If
   `kubectl` fails or returns no PVs, leave the existing snapshot alone. A
   bootstrap restart right before a delete refreshes it.
- **Step 7: restore.** On the create path, after `k3d cluster create --wait` and
   **before** the GitOps apply (the first thing that can create a PVC):
   when a snapshot exists, `kubectl apply` its PVs. Each `local` PV whose
   directory is missing under `storageDir` is skipped with a WARN, so a PV is
   never bound to an empty path. A PV whose `claimRef` names a PVC that does
   not exist yet is *pre-bound*. When ArgoCD creates that PVC, including a
   StatefulSet's `data-postgres-0`, the PV controller binds it to that PV
   instead of provisioning a new one. That holds for `WaitForFirstConsumer`
   (local-path) and for `Immediate` (nfs). Names, paths, sizes and reclaim
   policies stay exactly as they were.
- **Step 8: stable NFS address (factory-gitops).** Pin `clusterIP: 10.43.224.175`
   on the `nfs-provisioner` Service in `apps/nfs-provisioner/manifests/manifests.yaml`.
   On the running cluster that is the value it already has, so it is a no-op.
   On a new cluster (same default service CIDR `10.43.0.0/16`) the Service
   gets the same address, and the restored nfs PV's `server` stays valid. The
   provisioner re-exports its existing exports from the restored backing
   volume's `vfs.conf`.

### The recreate (runbook in the plan, run once, announced)

Before: all backups (keycloak, skillai pg_dump), the two undeclared Secrets
exported to a 0600 file, a fresh PV snapshot checked for 15 entries. Then
`k3d cluster delete`. While the cluster is stopped and the data is
consistent, a full `cp -a` of `storageDir` (16 GB; 602 GB free on
`/mnt/games`). Then create, which restores the PVs, and let ArgoCD sync. Re-apply
the two Secrets. Keep the copy for a week.

**A rehearsal comes first.** A throwaway k3d cluster on p620 (a different name
and port, its own storage dir) runs the same module logic end to end: a
StatefulSet and a plain PVC write a marker file, then snapshot, delete,
create, restore, and the pods read the markers back. The real recreate runs
only after the rehearsal passes.

## Alternatives rejected

- **Docker-wide `dns = [ … ]` in `daemon.settings`.** This changes where
  Docker's embedded resolver *forwards*, but containerd would still query
  `172.18.0.1`, the thing that refused connections. It does not remove the
  failing hop, and it changes DNS for every container on p620.
- **Re-write `/etc/resolv.conf` via `docker exec` on each bootstrap run,
  without a recreate.** No downtime, but it only runs at boot or timer time.
  A node restart between runs (09-22) reverts it, and the node is back on
  `172.18.0.1` until the next run.
- **Disable k3d's DNS fix (`K3D_FIX_DNS=0`).** It leaves the node on Docker's
  embedded resolver, which is the thing we are routing around. It also
  depends on a k3d env knob whose behaviour changes between k3d releases.
- **Chase the refusals to a root cause first.** Deferred by the intent.

## Risks

- **Recreate window (p620, factory cluster):** ArgoCD, factory and fides are
  down for the create. The history here (#1551 loop, 2026-08-11 phantom
  node) makes this the riskiest step, so it is manual, announced, and done
  after a rehearsal, backups and a full storage copy.
- **A PV does not rebind** (a changed name in GitOps, a race with ArgoCD):
  local-path provisions a new empty volume and the app starts empty. The
  guard is ordering (the restore runs before the GitOps apply) plus a check
  that every PVC is Bound to its *old* PV name before anything else is
  trusted. Recovery: scale the app down, delete the new PVC, and the
  pre-bound PV binds on recreate. The data was never touched: it is in the
  old directory and in the copy.
- **`10.43.224.175` taken** in the new cluster by a Service created before
  nfs-provisioner. The Service create then fails loudly and ArgoCD retries.
  The fix is to delete the squatter. The odds are small: the IP is random
  and the address space is a /16.
- **Snapshot staleness:** a PV created after the last snapshot is not
  restored. The runbook refreshes the snapshot right before the delete and
  checks the count.
- **Public resolvers unreachable:** if the host has no route to 1.1.1.1 or
  9.9.9.9 (captive or ISP outage), pulls fail. Today they would fail anyway,
  because Docker's resolver forwards to the ISP router. `resolvers` stays an
  option.
- **Name lookups for Docker-internal names from the node** stop working. None
  are used today. Adding a k3d registry later would need its address in
  `/etc/hosts` or the resolver. The option description will note this.

## Verification

1. `just test-host p620` builds.
2. After the deploy (no recreate): `/var/lib/k3d-factory/resolv.conf` exists
   with the two resolvers, and the bootstrap journal shows both smoke checks.
3. After the recreate: `docker inspect k3d-factory-server-0` shows both
   resolv mounts sourced from `/var/lib/k3d-factory/resolv.conf`, not
   `/nix/store`. `docker exec k3d-factory-server-0 cat /etc/resolv.conf`
   shows `1.1.1.1`/`9.9.9.9`, and `nslookup ghcr.io` inside the node works.
4. `docker restart k3d-factory-server-0`: after it comes up, the node's
   `/etc/resolv.conf` is still ours. This is the case that broke on 09-22.
5. A pod rolls out a fresh image from ghcr.io (`kubectl rollout restart` of
   one factory deployment) and reaches Running.
6. Rehearsal passes: marker files written before the delete are read back
   by the recreated pods, and their PVCs are Bound to the old PV names.
7. After the real recreate: all 15 PVCs are Bound to their pre-recreate PV
   names (compared against the snapshot), no new `pvc-*` dir appears under
   `storageDir`, the keycloak realm logs in, postgres and skillai-db list
   their tables, `tfactory-data-rwx` mounts with `projects.json` present,
   and every ArgoCD app is Synced/Healthy.
