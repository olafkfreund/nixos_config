# k3d Cluster on p510 — Operations

> **Public ingress note (2026-06-07):** services on this cluster are
> now exposed via **Cloudflare Tunnel** under our home domain
> (`<name>.<home-domain>`), not via Tailscale sidecars or tailnet
> hostnames. The Tailscale auth-key / sidecar machinery described
> further down this page is being decommissioned. For current public
> ingress design + how to add a new service, see
> [Public Ingress Architecture](../architecture/public-ingress.md)
> and [Cloudflared Tunnel](cloudflared-tunnel.md). The rest of this
> page covers cluster substrate (k3d, storage, bootstrap unit,
> kubeconfig) which is unchanged.

Single-node k3s-in-Docker cluster on p510, running ArgoCD + the Tailscale
Kubernetes Operator. For design rationale see
[architecture/k3d-architecture.md](../architecture/k3d-architecture.md).
For the day-to-day "I want to deploy a new service" workflow see
[guides/factory-gitops.md](../guides/factory-gitops.md).

## TL;DR

```bash
# On p510 (or any wheel-group shell with the kubeconfig synced):
sudo systemctl status k3d-cluster-bootstrap     # should be active (exited)
kubectl get nodes                                # 1 Ready node
kubectl -n argocd get pods                       # all Running
kubectl -n tailscale get secret auth-key          # bootstrap-seeded auth-key Secret
kubectl -n argocd get secret tailscale-auth-key   # copy into argocd ns
```

The cluster is owned by `systemd.services.k3d-cluster-bootstrap`. Re-running
it is the answer to most "something drifted" questions:

```bash
sudo systemctl restart k3d-cluster-bootstrap
sudo journalctl -u k3d-cluster-bootstrap -f
```

## First-time bring-up

This is the order you have to do things in. Skipping a step gives confusing
errors later.

### 1. Generate a Tailscale auth key (one-time, manual)

1. Open <https://login.tailscale.com/admin/settings/keys> → **Generate auth key…**
2. Description: `k3d-factory sidecar pool`
3. **Reusable**: yes (same key seeds the Secret in every namespace running sidecars)
4. **Ephemeral**: no (sidecar-registered nodes persist across pod restarts so hostnames stay stable)
5. **Expiry**: 90 days (Tailscale's maximum)
6. **ACL**: no changes needed — the default open policy works for the sidecar pattern
7. Copy the `tskey-auth-…` token — it's only shown once

### 2. Put the auth key in agenix

```bash
cd ~/.config/nixos
./scripts/manage-secrets.sh edit tailscale-k8s-operator-oauth
# Paste a single line: the raw tskey-auth-… token (no JSON, no quotes)
```

The blob is encrypted to p510's host key (and your user key) — see
`secrets.nix` for who can read it.

> The agenix slot is **named** `tailscale-k8s-operator-oauth` for
> historical reasons (an earlier iteration of this design targeted the
> Tailscale Kubernetes Operator). The **contents** are now a plain auth
> key. See `docs/architecture/k3d-architecture.md` "Why sidecars and not
> the operator" for the rationale.

### 3. Create the GitOps repo on GitHub

The bootstrap unit `kubectl apply -k`s from
`https://github.com/olafkfreund/factory-gitops` by default. If the repo
doesn't exist yet the bootstrap unit will log a warning and remain active
without ArgoCD installed — the cluster itself is still healthy.

Minimum layout for the bootstrap apply to succeed:

```text
factory-gitops/
├── bootstrap/
│   ├── kustomization.yaml                  # inlines upstream argo-cd v2.13.1 URL
│   ├── argocd-namespace.yaml
│   ├── argocd-sidecar-patch.yaml           # adds Tailscale sidecar to argocd-server
│   ├── argocd-tailscale-serve-config.yaml  # Tailscale Serve cfg (:443 → :8080)
│   └── argocd-root-app.yaml                # App-of-Apps root
└── apps/
    └── (one Application per Factory component, added later)
```

See [guides/factory-gitops.md](../guides/factory-gitops.md) for the full
file contents.

### 4. Deploy

```bash
just test-host p510            # local pre-flight
just quick-deploy p510         # apply on p510
```

The `k3d-cluster-bootstrap.service` runs as part of the activation. First
run takes 2–4 minutes (image pulls). Subsequent host reboots take seconds
— the cluster persists in Docker volumes.

### 5. Verify

```bash
ssh p510

systemctl status k3d-cluster-bootstrap    # Active: active (exited)
journalctl -u k3d-cluster-bootstrap -b    # full log, no errors

kubectl get nodes                                 # 1 Ready node
kubectl -n argocd get pods                        # argocd-server etc. Running
kubectl -n tailscale get secret auth-key          # bootstrap-seeded
kubectl -n argocd get secret tailscale-auth-key   # copy into argocd

# ArgoCD initial admin password:
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d; echo
```

Once the in-cluster Cloudflare Tunnel has the ArgoCD route in its
ConfigMap and the matching DNS record exists:

- ArgoCD UI: `argocd.<home-domain>`
- Login: `admin` + the password from above

(The Tailscale-sidecar exposure path that this section previously
described is deprecated; see the public-ingress note at the top of
this page.)

If the sidecar isn't running yet (first cluster bring-up takes a few
minutes), fall back to a port-forward:

```bash
kubectl -n argocd port-forward svc/argocd-server 8080:443
# → https://localhost:8080
```

## Day-2 ops

### Drive the cluster from your laptop

The kubeconfig at `/etc/k3d/kubeconfig` is local to p510 — it points at
`https://127.0.0.1:6443`. To use it from your laptop, rewrite the server
URL to `https://p510:6443` and `scp` the file. **But:** the kube API is
only bound to 127.0.0.1, so you'd need an SSH tunnel:

```bash
# On laptop:
ssh -L 6443:127.0.0.1:6443 p510 -N &
scp p510:/etc/k3d/kubeconfig ~/.kube/factory-config
sed -i 's|server: https://0.0.0.0:.*|server: https://127.0.0.1:6443|' \
  ~/.kube/factory-config
export KUBECONFIG=~/.kube/factory-config
```

Alternatively, just `ssh p510` and use the host-side `KUBECONFIG` env var
that the module sets cluster-wide.

### Trigger a manual ArgoCD sync

```bash
kubectl -n argocd patch application root \
  --type merge -p '{"operation":{"sync":{}}}'
```

Or use the ArgoCD UI / CLI:

```bash
argocd app sync root
```

### Add an agent node (future)

Single-server is fine for now. If you ever need to add agents:

```bash
k3d node create agent-0 --cluster factory --role agent
```

You'll also want to set `--servers 1 --agents N` permanently in the
module's `k3d cluster create` call — `modules/containers/k3d.nix` is the
place to edit.

### Rotate the Tailscale auth key

Auth keys expire (default 90d cap). When yours is close to expiry:

1. Generate a new auth key in the admin console (same settings: reusable, non-ephemeral, 90d).
2. `./scripts/manage-secrets.sh edit tailscale-k8s-operator-oauth`, replace the contents with the new `tskey-auth-…` token.
3. `just quick-deploy p510` — agenix decrypts the new key, but the
   in-cluster `tailscale-auth-key` Secrets won't refresh until you
   bounce the bootstrap unit:

   ```bash
   sudo systemctl restart k3d-cluster-bootstrap
   # Then bounce any sidecar-running pods so they re-register with the new key:
   kubectl -n argocd rollout restart deploy/argocd-server
   kubectl -n factory rollout restart deploy --all
   ```

4. Revoke the old key in the admin console once the new one is verified.

## Troubleshooting

### Bootstrap unit reports "WARN: …oauth not readable yet"

The agenix secret hasn't been created. Run step 2 of first-time bring-up,
then `systemctl restart k3d-cluster-bootstrap`.

### `kubectl apply -k` fails in the bootstrap log

The GitOps repo doesn't exist, or the `bootstrap/` path inside it is
malformed. The cluster is fine; ArgoCD just isn't installed yet. Fix the
repo, then restart the unit.

### Sidecar pod is `CrashLoopBackOff` with "auth key invalid"

The auth key has expired, been revoked, or never made it into the in-cluster Secret.

```bash
# Is the Secret populated?
kubectl -n argocd get secret tailscale-auth-key -o jsonpath='{.data.TS_AUTHKEY}' | base64 -d | head -c 20; echo
# Should print something starting with `tskey-auth-`. If empty:
sudo systemctl restart k3d-cluster-bootstrap
sudo journalctl -u k3d-cluster-bootstrap -b | grep -i tailscale
```

If the key is correctly seeded but the sidecar still fails, the key is expired/revoked — rotate (above).

### Cluster won't start after host reboot

Since the 2026-06-25 hardening this is **handled automatically** — the
bootstrap unit verifies the host API is reachable and self-heals the
serverlb port-publish race with a non-destructive `stop`/`start` cycle.
See [Disaster Recovery & Resilience](#disaster-recovery--resilience).

If the API is still unreachable from the host after boot:

```bash
docker ps -a --filter "name=k3d-${CLUSTER:-factory}"
# Did the self-heal run?
sudo journalctl -u k3d-cluster-bootstrap -b | grep -iE "self-heal|unreachable|reachable"
# Force a clean, NON-DESTRUCTIVE re-run (preserves all state):
sudo systemctl restart k3d-cluster-bootstrap
```

If Docker itself didn't start, that's a different problem — check
`systemctl status docker`.

### Full reset

Destroys the cluster and all in-cluster PVC data. ArgoCD will re-sync
everything from Git after re-bootstrap; non-Git state (manually-created
Secrets, e.g. the OAuth one) is re-seeded by the bootstrap unit.

```bash
sudo systemctl stop k3d-cluster-bootstrap
sudo $(which k3d) cluster delete factory
sudo rm -rf /mnt/img_pool/k3d/storage/* /etc/k3d/kubeconfig
sudo systemctl start k3d-cluster-bootstrap
sudo journalctl -u k3d-cluster-bootstrap -f
```

## Disaster Recovery & Resilience

> Captures the 2026-06-25 p510 incident and the hardening that followed, so
> this is on file for the next time. **A normal reboot now self-recovers with
> no manual steps** — the procedures below are for the rarer cases.

### Background: the 2026-06-25 incident

After a p510 reboot the factory cluster failed to recover cleanly and a
cascade followed. Root causes:

1. **serverlb port-publish race.** The k3d load balancer publishes the kube
   API on the host's tailnet IP (`100.118.96.32:6443`). On boot, Docker's
   `unless-stopped` restart policy resurrected the serverlb *before*
   `tailscale0` was up, so the port silently never published and
   `k3d cluster start` no-op'd on the "already running" containers → API
   unreachable from the host.
2. **Destructive recovery.** A `systemctl restart docker` taken to fix the LB
   instead tore the whole cluster down (force-stopped containers + a
   concurrent `Restart=on-failure` `k3d cluster create`).
3. **Non-declarative secrets lost on recreate.** Ten factory Secrets had been
   created out-of-band (`kubectl create secret`) — never in agenix or GitOps —
   so the forced recreate wiped them: `oauth2-proxy-{cfactory,observe,odin}`,
   `cfactory-api-keys`, `minio-creds`, `factory-db-{ai,p,t}factory`,
   `observe-root`, `otel-otlp-auth`, `odin-ssh-key`.
4. **Keycloak realm on ephemeral H2.** Keycloak runs `start-dev` (embedded
   H2) on a dynamic local-path PVC; a recreate gives it a fresh empty
   directory, so the `factory` realm + all OAuth clients were lost (recovered
   only because the previous H2 file lingered orphaned on disk).
5. **Keycloak liveness probe too aggressive.** Under post-reboot load the
   Quarkus `start-dev` build exceeded the liveness budget (~180s) and the pod
   was killed mid-start in an infinite crash-loop.

### What's now in place (hardening)

| Fix | Where | Guarantee |
|---|---|---|
| Bootstrap reboot self-heal | `modules/containers/k3d.nix` | After `k3d cluster start`, verifies the **host** API answers (`/readyz` via the published serverlb port); if not, non-destructive `stop`/`start` cycle (×5) rebuilds the LB port mapping. **No delete** — PVCs/etcd/realm preserved. |
| Order after tailscale + bind-IP wait | same | Unit ordered `after = tailscaled`; waits for the API bind IP to appear on an interface before cluster ops — kills the race at the source. |
| All factory Secrets in agenix | `secrets/factory-secret-*.age` + the `factorySecrets` seed loop in `k3d.nix` | The bootstrap `kubectl apply`s all 19 Secrets every run → a recreate self-restores them. |
| Keycloak startupProbe | `factory-gitops/infra/keycloak/keycloak.yaml` | 600s startup budget (`failureThreshold: 60 × 10s`) gates liveness → no crash-loop on slow start. |
| Keycloak realm backup | `keycloak-realm-backup.timer` (daily) | Copies the live realm H2 DB to `/mnt/img_pool/k3d/backups/keycloak/`. |

### Normal reboot — what happens automatically (no action needed)

On boot, `k3d-cluster-bootstrap` (after `tailscaled`):

1. waits for the tailnet bind IP, then `k3d cluster start`;
2. **verifies the host API answers** (`/readyz`); self-heals the LB with a
   non-destructive `stop`/`start` cycle if not;
3. **re-seeds all 19 agenix Secrets** (idempotent);
4. Keycloak restarts under the **startupProbe** with its realm intact.

A graceful reboot preserves all PVCs/etcd/realm — recovery is in-place.

### Post-reboot verification checklist

```bash
KC=/tmp/kc; sudo k3d kubeconfig get factory > "$KC"
# 1. cluster API reachable from the host (the serverlb race fix)
KUBECONFIG=$KC kubectl get nodes
# 2. did the self-heal run? (only logs if it had to act)
sudo journalctl -u k3d-cluster-bootstrap -b | grep -iE "self-heal|unreachable|reachable"
# 3. Keycloak back with realm, RESTARTS should stay 0
KUBECONFIG=$KC kubectl get pods -n factory -l app=keycloak
# 4. anything unhealthy?
KUBECONFIG=$KC kubectl get pods -n factory | grep -vE "Running|Completed"
```

### Manual recovery procedures

#### A. API unreachable after boot (self-heal didn't catch it)

Non-destructive — preserves all state:

```bash
sudo systemctl restart k3d-cluster-bootstrap        # re-runs the self-heal loop
# or drive it by hand:
sudo $(which k3d) cluster stop factory && sudo $(which k3d) cluster start factory
sudo docker inspect k3d-factory-serverlb --format '{{json .NetworkSettings.Ports}}'  # 6443 must be published
```

#### B. Restore the Keycloak realm (empty realm after a full recreate)

The realm/clients/users live in `keycloakdb.mv.db`. Restore it from the daily
backup (or an orphaned old PVC dir). **Disable ArgoCD auto-sync first** or it
will fight the scale-down:

```bash
KC=/tmp/kc; sudo k3d kubeconfig get factory > "$KC"; export KUBECONFIG=$KC
# 1. stop ArgoCD reverting us, then scale Keycloak down
kubectl patch application root     -n argocd --type json -p '[{"op":"remove","path":"/spec/syncPolicy/automated"}]'
kubectl patch application keycloak -n argocd --type json -p '[{"op":"remove","path":"/spec/syncPolicy/automated"}]'
kubectl scale deploy -n factory keycloak --replicas=0
kubectl wait --for=delete pod -n factory -l app=keycloak --timeout=60s
# 2. find the live PVC dir and drop the backup H2 into it
VOL=$(kubectl get pvc keycloak-data -n factory -o jsonpath='{.spec.volumeName}')
DST="/mnt/img_pool/k3d/storage/$(kubectl get pv "$VOL" -o jsonpath='{.spec.local.path}' | xargs basename)/h2"
sudo mkdir -p "$DST"
sudo cp /mnt/img_pool/k3d/backups/keycloak/keycloakdb-latest.mv.db "$DST/keycloakdb.mv.db"
sudo chown -R 1000:1000 "$(dirname "$DST")"
# 3. bring it back, then re-enable ArgoCD
kubectl scale deploy -n factory keycloak --replicas=1
kubectl patch application root     -n argocd --type merge -p '{"spec":{"syncPolicy":{"automated":{"prune":true,"selfHeal":true}}}}'
kubectl patch application keycloak -n argocd --type merge -p '{"spec":{"syncPolicy":{"automated":{"prune":true,"selfHeal":true}}}}'
```

Verify the realm came back:

```bash
kubectl exec -n factory deploy/keycloak -- sh -c '
  /opt/keycloak/bin/kcadm.sh config credentials --server http://localhost:8080 \
    --realm master --user "$KC_BOOTSTRAP_ADMIN_USERNAME" --password "$KC_BOOTSTRAP_ADMIN_PASSWORD" &&
  /opt/keycloak/bin/kcadm.sh get realms --fields realm'
```

#### C. A missing/incorrect oauth2-proxy Secret (proxy 502/403, pod `CreateContainerConfigError`)

These are now in agenix, so the durable fix is just:

```bash
sudo systemctl restart k3d-cluster-bootstrap   # re-seeds all factory Secrets from agenix
```

To rebuild one by hand from the live Keycloak client (e.g. odin → client
`odin-dashboard`), the Secret needs `client-id`, `client-secret`,
`cookie-secret`:

```bash
ID=$(kubectl get clients ... )   # internal id of the client in realm factory via kcadm
SECRET=$(kubectl exec -n factory deploy/keycloak -- /opt/keycloak/bin/kcadm.sh get clients/$ID/client-secret -r factory | jq -r .value)
COOKIE=$(openssl rand -hex 16)   # MUST decode to 16/24/32 bytes; -base64 32 (=44 chars) is INVALID
kubectl create secret generic oauth2-proxy-odin -n factory \
  --from-literal=client-id=odin-dashboard --from-literal=client-secret="$SECRET" \
  --from-literal=cookie-secret="$COOKIE" --dry-run=client -o yaml | kubectl apply -f -
```

> ⚠️ `cookie-secret` gotcha: oauth2-proxy requires exactly **16, 24, or 32
> bytes**. `openssl rand -base64 32` yields a 44-char string (44 bytes) and
> crash-loops with `cookie_secret must be 16, 24, or 32 bytes`. Use
> `openssl rand -hex 16` (32 chars) or `openssl rand -base64 24` (32 chars).

#### D. Re-capture a live Secret into agenix (make it durable)

Run on p510 (it holds both the live Secrets and the agenix recipient keys).
Encrypt to recipients `olafkfreund` + `p510` (see `secrets.nix`), copy the
`.age` into `secrets/`, add it to `secrets.nix` and the `factorySecrets` seed
loop in `modules/containers/k3d.nix`:

```bash
kubectl get secret <name> -n factory -o json \
  | jq '{apiVersion, kind, type, data, metadata:{name:.metadata.name}}' \
  | age -r "<olafkfreund pubkey>" -r "<p510 pubkey>" -o factory-secret-<name>.age
```

### Backups

- **Daily** via `keycloak-realm-backup.timer` →
  `/mnt/img_pool/k3d/backups/keycloak/keycloakdb-{TIMESTAMP,latest}.mv.db`
  (14 timestamped copies kept).
- **On demand:** `sudo systemctl start keycloak-realm-backup.service`
- ⚠️ Backups live on the **same disk** as the cluster — fine for
  recreate/corruption recovery, **not** full disk loss. Add an off-host copy
  (rsync/restic to p620 or object storage) for true DR.

### Known residual gaps

- **App databases** (postgres/minio PVCs) have **no restore automation** — a
  full cluster *recreate* rebuilds them empty. The hardened bootstrap now
  *avoids* recreate (it self-heals in place), so this is a rare-catastrophe
  gap, not an everyday one. Adding per-DB dump timers + restore-on-bootstrap
  would close it.
- The reboot self-heal logic is deployed but was **not yet validated with a
  live reboot** (deferred). Run the verification checklist after the next
  natural reboot.

## What's running where

| Component | Namespace | How it got there | Owner |
|---|---|---|---|
| k3s server | (host Docker) | `k3d cluster create` from bootstrap unit | This module |
| Local-path provisioner | `kube-system` | Ships with k3s | k3s upstream |
| ArgoCD | `argocd` | `kubectl apply -k` from bootstrap unit | `factory-gitops/bootstrap/` |
| ArgoCD root Application | `argocd` | Part of bootstrap kustomization | `factory-gitops/bootstrap/argocd-root-app.yaml` |
| ArgoCD Tailscale sidecar | `argocd` (patched onto `argocd-server`) | Kustomize patch in bootstrap/ | `factory-gitops/bootstrap/argocd-sidecar-patch.yaml` |
| `tailscale/auth-key` Secret | `tailscale` | Created by bootstrap unit from agenix | This module |
| `argocd/tailscale-auth-key` Secret | `argocd` | Copied by bootstrap unit | This module |
| `factory/tailscale-auth-key` Secret | `factory` | Copied by bootstrap unit | This module |
| Factory components | `factory` (planned) | ArgoCD Applications under `apps/` | `factory-gitops/apps/<name>/` |

## Related files

- Module: `modules/containers/k3d.nix` (bootstrap, reboot self-heal, backup timer)
- Host enable: `hosts/p510/configuration.nix` (search for `modules.containers.k3d`)
- Secrets: `secrets.nix` → `tailscale-k8s-operator-oauth` + `factory-secret-*` slots
- Encrypted Secret manifests: `secrets/factory-secret-*.age` (19 slots, seeded by the bootstrap)
- Keycloak manifest (startupProbe): `factory-gitops/infra/keycloak/keycloak.yaml`
- Realm backups: `/mnt/img_pool/k3d/backups/keycloak/` (daily `keycloak-realm-backup.timer`)
- Architecture: [k3d Architecture](../architecture/k3d-architecture.md)
- GitOps workflow: [Factory GitOps](../guides/factory-gitops.md)
