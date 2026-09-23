---
status: draft
issue: 1497
intent: intent/2026-09-23-1497-k3d-node-resolv-conf.md
---

# Spec: k3d image pulls survive Docker's embedded resolver

Decisions from the intent approval: declaring the resolver is enough, and we
don't block on the exact root cause (open question 2). This spec settles the
width of the fix (open question 1): **node-scoped, not Docker-wide.** The
evidence is below.

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

### Rollout needs a planned cluster recreate

Mounts are fixed at container create, so the live `factory` cluster only
adopts step 2 through `k3d cluster delete` plus a bootstrap. PVCs live in
`storageDir` (`/mnt/games/k3d/storage`) and survive a recreate by design.
Take a keycloak backup first (`keycloak-realm-backup`). Do it as its own
announced window on the agent bus, not as a side effect of a deploy.

Until that window, the deployed module still helps: it gives the smoke check
and the stable file. And the existing hand repair (`docker exec … sh -c 'cat
> /etc/resolv.conf'`) keeps working until the next container restart.

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
  after a backup.
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
