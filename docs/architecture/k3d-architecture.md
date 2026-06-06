# k3d Cluster on p510 — Architecture

## Why this exists

The Factory project (AIFactory, PFactory, TFactory, CFactory) and a handful
of other personal services need a real Kubernetes environment for ArgoCD-
driven GitOps deployment, with each service reachable on the tailnet under
its own hostname. p510 is the natural home: it already runs Docker for the
media stack, has spare CPU and RAM, and lives on a stable LAN.

## Why k3d (and not k3s-in-MicroVMs, k0s, kind, …)

| Option | Decision | Why |
|---|---|---|
| **k3d (chosen)** | ✅ | k3s inside the host Docker daemon. Zero extra hypervisor. Cluster lifecycle is one `k3d` command. Persistent state via Docker volumes. |
| k3s in MicroVMs | ❌ | The repo already has dormant MicroVM k3s files (`hosts/p510/nixos/microvm/k3s-*.nix`) that were never wired up. Heavier (KVM + dedicated kernels) for no isolation win on a single-tenant host. |
| kind | ❌ | Effectively equivalent to k3d in mechanics. k3d wins on first-class k3s features (servicelb, traefik on/off flags, embedded registry support). |
| k0s / k8s upstream | ❌ | Overkill for a homelab — k3s ships everything we need (containerd, CoreDNS, local-path-provisioner) at a fraction of the surface area. |
| Plain Docker Compose | ❌ | Doesn't match the Factory project's intended target environment, and ArgoCD-based GitOps is the requirement. |

## Why this won't break the existing media stack

p510's media services (Plex, Sonarr, Radarr, Tautulli, NZBGet, Backstage,
…) are exposed today via host-level `tailscale serve --https=443 ...` with
path-based routing (`p510.tail833f7.ts.net/sonarr`, etc.). The k3d cluster
**does not touch host port 443**.

- Tailnet exposure for cluster services uses the **sidecar pattern**:
  each Pod that needs a tailnet hostname runs an in-pod `tailscale`
  container that joins the tailnet from inside the cluster. This is
  entirely independent of the host's `tailscaled` and host-level
  `tailscale serve` configuration.
- k3d binds the kube API to `127.0.0.1:6443` only. Not reachable from LAN
  or tailnet directly; you drive it from p510 via the host-side kubeconfig
  at `/etc/k3d/kubeconfig` (mode 0640, group `wheel`).
- Persistent volumes live under `/mnt/img_pool/k3d/storage` — off
  `/mnt/media` so PVCs don't fight Plex for IOPS.

## Why sidecars and not the Tailscale Kubernetes Operator

The operator is the "obviously right" answer in most Kubernetes contexts —
one annotation on a Service and the operator handles everything. We
chose sidecars instead because:

1. **The operator requires OAuth client credentials** (`Settings → OAuth
   clients` in the Tailscale admin), and this homelab is wired with a
   plain auth key (`Settings → Keys`). The operator does not accept
   auth keys; this is a hard constraint of its Helm chart.
2. **The sidecar pattern works with what we have today** — one auth key,
   stored in agenix, copied into a Kubernetes Secret in each consuming
   namespace by the bootstrap unit. No CRDs, no extra control-plane
   pod.
3. **The boilerplate cost is manageable.** Each Tailscale-exposed Pod
   adds one container + two env refs. The pattern is documented in
   [guides/factory-gitops.md](../guides/factory-gitops.md) so copy-paste
   is the workflow.

The cost we accept:

- **Auth-key rotation is manual.** Tailscale caps key TTL at 90 days
  (longer if you mark the key reusable + non-ephemeral, which we do).
  Rotation = `manage-secrets.sh edit tailscale-k8s-operator-oauth`,
  restart the bootstrap unit, bounce the Pods. The operator would
  rotate automatically.
- **No "expose this Service" annotation.** You have to edit the
  Deployment to add the sidecar; you can't promote an arbitrary
  pre-existing Service to the tailnet without re-templating its
  workload.

If at some point an OAuth client becomes available (you generate one in
the admin console), the migration is straightforward: replace the
agenix secret's contents with JSON `{client_id, client_secret}`, swap
`tailscaleAuthKey.enable` for `tailscaleOperator.enable`, deploy the
operator via an ArgoCD Application, drop sidecars from individual
Deployments.

## High-level shape

```
┌─────────────────────────────── p510 host ────────────────────────────────┐
│                                                                           │
│  existing services (untouched)        new k3d cluster (Docker)            │
│  ────────────────────────────         ────────────────────────             │
│   plex 32400                          ┌─────────────────────────────┐    │
│   sonarr 8989  ──┐                    │  k3d-factory-server-0       │    │
│   radarr 7878    │                    │  (k3s server, 1 node)       │    │
│   …media stack…  │                    │                             │    │
│                  │                    │  argocd ns                  │    │
│   tailscale ┐    │                    │  tailscale ns (operator)    │    │
│   serve :443│←───┘ path routing       │  factory ns (aifactory,…)   │    │
│             │                         │                             │    │
│             │                         │  local-path PVCs →           │    │
│  tailscaled │                         │   /mnt/img_pool/k3d/storage │    │
│  daemon     │                         └────────┬────────────────────┘    │
│             ↓                                  │ ts-operator spawns       │
│  tailnet ──────────────── tailnet ─────────── proxy pods, one per         │
│  p510.ts.net (host)                          exposed service              │
│  argocd.ts.net  ←─────────────────────────────┘                          │
│  aifactory.ts.net                                                         │
│  …                                                                        │
└───────────────────────────────────────────────────────────────────────────┘
                              ↑
                              │ GitOps pull
                              │
            github.com/olafkfreund/factory-gitops (App-of-Apps)
              ├── bootstrap/      ← applied once by Nix
              ├── infrastructure/ ← tailscale-operator, cert-manager, …
              └── apps/           ← aifactory, pfactory, tfactory, cfactory, …
```

## Module surface

The single source of truth is `modules/containers/k3d.nix`:

| Option | Default | Purpose |
|---|---|---|
| `modules.containers.k3d.enable` | `false` | Master switch. |
| `clusterName` | `"factory"` | Docker container prefix + `k3d` selector. |
| `apiPort` | `6443` | Bound to `127.0.0.1` only. |
| `storageDir` | `/mnt/img_pool/k3d/storage` | Bind-mounted as the local-path-provisioner backend. |
| `kubeconfigPath` | `/etc/k3d/kubeconfig` | Written `0640` group `wheel`. Also exported as `KUBECONFIG` host-wide. |
| `argocd.enable` | `false` | Whether to `kubectl apply -k` the bootstrap kustomization after cluster create. |
| `argocd.gitopsRepo` | `https://github.com/olafkfreund/factory-gitops` | Source of the bootstrap. |
| `argocd.bootstrapPath` | `bootstrap` | Path inside the repo. |
| `tailscaleAuthKey.enable` | `false` | Whether to materialise a Kubernetes Secret containing the Tailscale auth key for sidecar consumption. |
| `tailscaleAuthKey.authKeyFile` | `config.age.secrets.tailscale-k8s-operator-oauth.path` | Raw `tskey-auth-…` token, one line, no JSON wrapping. |
| `tailscaleAuthKey.targetNamespaces` | `[ "argocd" "factory" ]` | Namespaces that receive a copy of the `tailscale-auth-key` Secret (in addition to the canonical one in `tailscale`). |

Assertions:

- `modules.containers.docker.enable` must be true (k3d uses host Docker).

## Bootstrap unit lifecycle

`systemd.services.k3d-cluster-bootstrap` is a one-shot, `RemainAfterExit`,
idempotent — safe to `systemctl restart` at any time.

1. Wait for `docker.service` and `network-online.target`.
2. If the cluster doesn't exist → `k3d cluster create` with `traefik` and
   `servicelb` disabled (we use the Tailscale operator for exposure
   instead of Klipper-LB).
3. If the cluster exists but is stopped → `k3d cluster start`.
4. Write `/etc/k3d/kubeconfig` (chgrp wheel, chmod 0640).
5. Wait up to 60 s for the kube API to accept requests.
6. (If `tailscaleAuthKey.enable`) Create the `tailscale` namespace,
   read the raw auth-key from agenix, then `kubectl apply` a Secret
   `tailscale/auth-key` with key `TS_AUTHKEY`. Then for each namespace
   in `targetNamespaces` (default `argocd`, `factory`): create the
   namespace if missing, copy the Secret as `tailscale-auth-key`.
7. (If `argocd.enable`) `kubectl apply -k <gitopsRepo>//<bootstrapPath>?ref=main`
   — installs ArgoCD plus the App-of-Apps root.

Failure semantics: `Restart=on-failure`, `RestartSec=10s`. If the GitOps
repo doesn't exist yet, the unit logs a warning and stays "active" —
re-run with `systemctl restart k3d-cluster-bootstrap` once the repo is
populated.

## Secrets

| Name | Format | Created via |
|---|---|---|
| `tailscale-k8s-operator-oauth.age` | Single line — raw `tskey-auth-…` auth key. (Filename kept for back-compat with the operator-flavoured plan; contents are now the auth key, not OAuth JSON.) | `./scripts/manage-secrets.sh edit tailscale-k8s-operator-oauth` |

Auth key setup (one-time, in the Tailscale admin console):

1. Visit <https://login.tailscale.com/admin/settings/keys> → "Generate auth key…"
2. **Reusable**: yes (same key seeds the Secret in every consuming namespace)
3. **Ephemeral**: no (so sidecar-registered nodes persist across pod restarts)
4. **Expiry**: 90 days (Tailscale's maximum)
5. Description: e.g. `k3d-factory sidecar pool`
6. Paste the resulting `tskey-auth-…` token into the agenix slot
7. ACL: **no changes required**. The default open ACL allows the sidecar-registered nodes to be reached from your other tailnet devices.

## Decision log

- **2026-06-06** — Standalone `modules/containers/k3d.nix`, opt-in per host
  (NOT in `modules/containers/default.nix`). Adding to the aggregator would
  pull k3d onto p620 (which inherits the workstation template), which we
  don't want.
- **2026-06-06** — Dropped a planned `k3d-cluster-token` agenix entry. k3d
  generates its own server token; we don't have agents to join, so a
  persisted token would be dead weight.
- **2026-06-06** — Bootstrap runs as root, not DynamicUser — it needs
  Docker socket access and writes to `/etc/k3d`. Workloads themselves run
  inside k3d/k3s containers with their own isolation.
- **2026-06-06** — Traefik and servicelb disabled at cluster create time.
  The Tailscale operator handles exposure; in-cluster Service routing
  uses kube-proxy + CoreDNS only.
- **2026-06-06** — kube API bound to `127.0.0.1:6443`. Host firewall is
  already disabled on p510, but the explicit loopback bind makes it
  obvious that LAN/tailnet should not reach the API directly.
- **2026-06-06 (later)** — **Pivoted from Tailscale K8s Operator to
  sidecar pattern.** Operator requires OAuth client credentials; this
  homelab has a plain auth key. Sidecars work with what we have at
  the cost of per-Pod boilerplate and manual key rotation. The
  agenix slot kept its `-operator-oauth` name to avoid touching
  `secrets.nix`; the contents are now a raw auth key. Future
  migration to the operator is a value-shape change + module option
  swap; nothing structural breaks.

## Cross-references

- Ops + troubleshooting: [k3d Cluster](../applications/k3d-cluster.md)
- Adding services via GitOps: [Factory GitOps](../guides/factory-gitops.md)
- Module source: `modules/containers/k3d.nix`
- Module wiring: `hosts/p510/configuration.nix`
- Secret registration: `secrets.nix`
