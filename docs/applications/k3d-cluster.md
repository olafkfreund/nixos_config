# k3d Cluster on p510 — Operations

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

Once the Tailscale sidecar on `argocd-server` has registered (≈ 30 s
after the Pod is Ready):

- ArgoCD UI: `https://argocd.tail833f7.ts.net`
- Login: `admin` + the password from above

Confirm registration:

```bash
kubectl -n argocd logs deploy/argocd-server -c tailscale | grep -iE 'success|registered|hostname'
```

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

```bash
docker ps -a --filter "name=k3d-${CLUSTER:-factory}"
# Should show server + tools containers; if not:
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

- Module: `modules/containers/k3d.nix`
- Host enable: `hosts/p510/configuration.nix` (search for `modules.containers.k3d`)
- Secrets: `secrets.nix` → `tailscale-k8s-operator-oauth`
- Architecture: [k3d Architecture](../architecture/k3d-architecture.md)
- GitOps workflow: [Factory GitOps](../guides/factory-gitops.md)
