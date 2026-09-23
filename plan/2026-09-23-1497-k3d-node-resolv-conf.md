---
status: approved
issue: 1497
spec: spec/2026-09-23-1497-k3d-node-resolv-conf.md
---

# Plan: k3d image pulls survive Docker's embedded resolver

## Approved decisions (self-contained)

- **The fix is node-scoped.** Docker's `daemon.settings.dns` stays unchanged.
  The reason: Docker-wide DNS only changes where `172.18.0.1` forwards, and
  containerd would still query `172.18.0.1`, the hop that refused.
- **Mount the declared resolver file over each node's `/etc/resolv.conf`**,
  next to the existing `/etc/rancher/k3s/resolv.conf` mount. containerd then
  queries `cfg.resolvers` (default `1.1.1.1`, `9.9.9.9`) directly. k3d
  v5.7.4's `k3d-entrypoint-dns.sh` rewrites the file only if it contains
  `127.0.0.11`, so it leaves ours alone.
- **Move both mounts off `/nix/store`** onto a stable host file,
  `/var/lib/k3d-<clusterName>/resolv.conf`. The bootstrap rewrites it in
  place (`cat > file`, same inode) on every run. The directory comes from
  `tmpfiles`.
- **Add a pull-path smoke check** (`docker exec <node> nslookup ghcr.io`).
  It warns only, the same as the pod DNS check, and its message names #1497
  and the need to delete pods stuck in `ImagePullBackOff`.
- **Adopting it on the live cluster needs a recreate.** That is a separate,
  announced window after a keycloak backup, never part of a deploy.
- Root cause (k3d's NAT rewrite vs Docker 29 + `live-restore`) is plausible
  but unproven. It is recorded in a comment, not chased.
- Rejected: Docker-wide `dns`, a `docker exec` rewrite without recreate,
  `K3D_FIX_DNS=0`, and root-causing first.

## Steps

All in `modules/containers/k3d.nix` unless noted.

1. `let` block: add `resolvStateFile = "/var/lib/k3d-${cfg.clusterName}/resolv.conf";`.
   Extend the `nodeResolvConf` comment by 2–3 lines: containerd reads the
   node's own `/etc/resolv.conf`, k3d's DNS-fix entrypoint rewrites Docker's
   NAT rules there, and the pull path failed three times (#1497).
   → verify with `just check-syntax`.
2. `systemd.tmpfiles.rules` (around line 654): add
   `"d /var/lib/k3d-${cfg.clusterName} 0755 root root - -"`.
3. Bootstrap script, right after `mkdir -p … "$STORAGE_DIR"` (around line 99)
   and before the create/start branch: `cat ${nodeResolvConf} > "${resolvStateFile}"`.
   → verify that the rendered script text contains it:
   `nix eval --raw .#nixosConfigurations.p620.config.systemd.services.k3d-bootstrap.script | grep resolv`
   (adjust the unit name to whatever the module names it).
4. `k3d cluster create` (around line 152): replace
   `--volume "${nodeResolvConf}:/etc/rancher/k3s/resolv.conf@all:*"` with two lines:

   ```sh
   --volume "${resolvStateFile}:/etc/resolv.conf@all:*" \
   --volume "${resolvStateFile}:/etc/rancher/k3s/resolv.conf@all:*" \
   ```

   Keep `--k3s-arg "--resolv-conf=/etc/rancher/k3s/resolv.conf@all:*"`.
5. After the pod DNS smoke check (around line 396), add the pull-path check:

   ```sh
   echo "[k3d-bootstrap] DNS smoke check (image pulls, node resolver)"
   if docker exec "k3d-$CLUSTER-server-0" nslookup ghcr.io >/dev/null 2>&1; then
     echo "[k3d-bootstrap] node DNS OK"
   else
     echo "[k3d-bootstrap] WARN: the node could NOT resolve ghcr.io, so image pulls will fail." \
          "Check that the node's /etc/resolv.conf is ${resolvStateFile}, not Docker's" \
          "172.18.0.1. After repairing, delete pods stuck in ImagePullBackOff. See #1497."
   fi
   ```

   → verify that `docker exec k3d-factory-server-0 nslookup ghcr.io` works today
   (`nslookup` exists in the node, as checked during the spec).
6. `resolvers` option description: it now governs both the node's
   `/etc/resolv.conf` and k3s's. Docker-internal container names do not
   resolve on the node. The recreate note stays.
7. `just check-syntax`, `just test-host p620` → exit 0.
8. Open the PR (links intent, spec and plan). Merge after review.
9. Announce on the agent bus, then deploy p620 → Test 1. The running cluster
   is untouched: the bootstrap takes the "already exists" path. It still
   writes the state file and runs both smoke checks.
    **Added during implementation:** the live node's k3s resolver mount
    comes from `/nix/store/ln8jljz69sgcj5f4kgq3r5y4qdxhg09j-k3d-node-resolv.conf`.
    The current system already does not reference it (the same content now
    hashes to a different path), so a GC would delete it under a running
    mount. Until the recreate, pin it:
    `sudo nix-store --add-root /nix/var/nix/gcroots/k3d-live-resolv -r /nix/store/ln8jljz69sgcj5f4kgq3r5y4qdxhg09j-k3d-node-resolv.conf`.
    Remove that root after step 10.
10. **Recreate window** (separate, needs the user's go-ahead and a bus
    announcement with the expected downtime):
    1. `systemctl start keycloak-realm-backup` and confirm a fresh file in
       the backup dir.
    2. `k3d cluster delete factory`.
    3. Start the bootstrap unit, which creates the cluster with the new
       mounts. ArgoCD re-syncs the workloads. PVCs come back from
       `/mnt/games/k3d/storage`.
    → Tests 2–4.

## Tests

1. After the deploy: `cat /var/lib/k3d-factory/resolv.conf` lists
   `nameserver 1.1.1.1` and `nameserver 9.9.9.9`, and the bootstrap journal
   shows `DNS OK` and `node DNS OK` (or the new WARN).
2. After the recreate:

   ```sh
   docker inspect k3d-factory-server-0 \
     --format '{{range .Mounts}}{{.Source}} -> {{.Destination}}{{println}}{{end}}' | grep resolv
   ```

   shows two mounts, both from `/var/lib/k3d-factory/resolv.conf` and none
   from `/nix/store`. `docker exec k3d-factory-server-0 cat /etc/resolv.conf`
   is our file, and `nslookup ghcr.io` inside the node works.
3. `docker restart k3d-factory-server-0`, then Test 2 again. The file is
   still ours. This is the 09-22 case.
4. `kubectl -n factory rollout restart deploy/<one ghcr.io-backed deployment>`
   → the new pod pulls and reaches Running. ArgoCD apps are Synced/Healthy.

## Rollback

- Before the recreate: revert the PR and deploy. The live cluster never used
  the new mounts, so nothing else changes.
- After the recreate, the quick fix is to edit the resolvers live: the node
  bind-mounts the host file, so rewriting
  `/var/lib/k3d-factory/resolv.conf` in place (`cat > …`, not `cp`) changes
  the node's resolver immediately, with no recreate. The full revert is to
  revert the PR, deploy, and recreate again, with a backup first.
