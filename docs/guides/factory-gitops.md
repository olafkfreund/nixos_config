# Factory GitOps — How to ship a service to the cluster

The k3d cluster on p510 is fed by a single GitOps repo:
**[olafkfreund/factory-gitops](https://github.com/olafkfreund/factory-gitops)**.
ArgoCD watches this repo and applies whatever it finds. Adding a service
is purely a Git workflow — no `kubectl apply` on p510, no SSH.

For cluster lifecycle / troubleshooting see
[applications/k3d-cluster.md](../applications/k3d-cluster.md). For the
"why" see [architecture/k3d-architecture.md](../architecture/k3d-architecture.md).

## Repo layout

```text
factory-gitops/
├── README.md
├── catalog-info.yaml                ← Backstage discovers this
├── mkdocs.yml + docs/               ← TechDocs source for this repo
├── bootstrap/                              ← Applied ONCE by Nix (k3d-cluster-bootstrap unit)
│   ├── kustomization.yaml                  ← inlines upstream argo-cd v2.13.1 URL
│   ├── argocd-namespace.yaml
│   ├── argocd-sidecar-patch.yaml           ← Tailscale sidecar patched onto argocd-server
│   ├── argocd-tailscale-serve-config.yaml  ← Tailscale Serve config (:443 → :8080)
│   └── argocd-root-app.yaml                ← App-of-Apps root Application
└── apps/                            ← One Application per product / service
    ├── aifactory/
    │   └── application.yaml
    ├── pfactory/
    │   └── application.yaml
    ├── tfactory/
    │   └── application.yaml
    └── cfactory/
        └── application.yaml
```

Note: there's **no `infrastructure/tailscale-operator/`** — we use the
Tailscale sidecar pattern instead of the operator (see
[architecture/k3d-architecture.md](../architecture/k3d-architecture.md)
"Why sidecars and not the Tailscale Kubernetes Operator").

The root Application (`bootstrap/argocd-root-app.yaml`) points at `apps/`
recursively. **Anything you commit under `apps/` becomes a managed
service automatically** — no extra registration step.

## The "add a new service" checklist

1. Write k8s manifests for the service somewhere ArgoCD can reach. The
   conventions:
   - Manifests live in the **product repo** (e.g.
     `github.com/olafkfreund/AIFactory/deploy/k8s/`), not in
     `factory-gitops`. `factory-gitops` only holds the ArgoCD `Application`
     CR that points there.
   - Or, for one-off tools without a dedicated repo, commit them straight
     under `factory-gitops/apps/<name>/manifests/`.
2. Add `factory-gitops/apps/<name>/application.yaml` (template below).
3. In the product repo's Deployment, add a Tailscale sidecar container
   (template below) — that's how a Pod becomes reachable on the tailnet.
4. `git push`. ArgoCD picks it up within ~3 minutes (or trigger a sync
   from the UI).
5. Verify: `https://<hostname>.tail833f7.ts.net` resolves once the
   sidecar has registered (~30 s after the Pod starts).

## Templates

### `apps/<name>/application.yaml`

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: aifactory
  namespace: argocd
  # Lets ArgoCD remove finalizers properly when the Application is deleted
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://github.com/olafkfreund/AIFactory
    targetRevision: main
    path: deploy/k8s
  destination:
    server: https://kubernetes.default.svc
    namespace: factory
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

### Pod exposed on the tailnet via a sidecar

Patch your Deployment to add a `tailscale` sidecar in the same Pod. The
sidecar shares the Pod's network namespace, registers a tailnet node
named `aifactory`, and proxies traffic to your app container on
localhost.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: aifactory
  namespace: factory
spec:
  replicas: 1
  selector: { matchLabels: { app: aifactory } }
  template:
    metadata: { labels: { app: aifactory } }
    spec:
      # Sidecar's iptables tweak needs this in older clusters; harmless on k3s.
      serviceAccountName: default
      containers:
        # ── your app ───────────────────────────────────────────────
        - name: app
          image: ghcr.io/olafkfreund/aifactory:0.1.0
          ports:
            - containerPort: 8080
        # ── Tailscale sidecar ──────────────────────────────────────
        - name: tailscale
          image: ghcr.io/tailscale/tailscale:v1.74.0
          env:
            - name: TS_AUTHKEY
              valueFrom:
                secretKeyRef:
                  name: tailscale-auth-key      # seeded by k3d-cluster-bootstrap
                  key: TS_AUTHKEY
            - name: TS_HOSTNAME
              value: "aifactory"                # → aifactory.tail833f7.ts.net
            - name: TS_USERSPACE
              value: "true"                     # no NET_ADMIN cap needed
            - name: TS_STATE_DIR
              value: "/tmp/tsstate"             # ephemeral state (reusable key
                                                #  means re-registration is fine)
            - name: TS_EXTRA_ARGS
              value: "--accept-dns=false"
          securityContext:
            runAsUser: 1000
            runAsNonRoot: true
```

Then point your Service at the app container on its own port. The Service
itself is **only used inside the cluster** — tailnet clients reach the
Pod directly via its tailnet hostname.

```yaml
apiVersion: v1
kind: Service
metadata:
  name: aifactory
  namespace: factory
spec:
  selector: { app: aifactory }
  ports: [ { port: 80, targetPort: 8080 } ]
```

**Hostname lookups:** `aifactory.tail833f7.ts.net` resolves from any
tailnet device once the sidecar has started (`kubectl -n factory logs
deploy/aifactory -c tailscale` shows registration progress).

### Where the auth-key Secret comes from

The bootstrap unit on p510 seeds `tailscale-auth-key` (key `TS_AUTHKEY`)
into the namespaces listed in `modules.containers.k3d.tailscaleAuthKey.targetNamespaces`
(default: `argocd`, `factory`). To run sidecars in a new namespace:

1. Add the namespace to that list in `hosts/p510/configuration.nix`.
2. `just quick-deploy p510`.
3. `systemctl restart k3d-cluster-bootstrap` on p510 (or just wait — the
   unit re-runs on every restart, and the next host reboot is enough).

## Operating ArgoCD

### Trigger a sync

```bash
# Via the CLI
argocd login argocd.tail833f7.ts.net   # uses initial admin password
argocd app sync root                   # cascades to all child Applications

# Via kubectl (works without argocd CLI)
kubectl -n argocd patch application root \
  --type merge -p '{"operation":{"sync":{}}}'
```

### See what's out of sync

```bash
argocd app list
kubectl -n argocd get applications -o wide
```

### Roll back

ArgoCD keeps a deploy history. Either the UI (Application → History and
Rollback) or:

```bash
argocd app rollback aifactory <revision-number>
```

## Don'ts

- **Don't `kubectl apply -f` anything in `apps/` namespaces by hand.**
  ArgoCD with `syncPolicy.automated.selfHeal: true` will revert it on the
  next sync.
- **Don't put secrets in plaintext in `factory-gitops`.** Use sealed-secrets,
  external-secrets, or hand-create them with `kubectl create secret` and
  set `syncPolicy.syncOptions: ["Replace=false"]` so ArgoCD doesn't try
  to manage them.
- **Don't bypass the `bootstrap/` flow.** ArgoCD itself is installed by
  the Nix bootstrap unit, not by an Application. If you destroy and
  rebuild the cluster, you go through the bootstrap unit again — not
  through `argocd app sync`.

## Worked example — adding AIFactory

```bash
# 1. In the AIFactory repo:
mkdir -p deploy/k8s
cat > deploy/k8s/deployment.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: aifactory
  namespace: factory
spec:
  replicas: 1
  selector: { matchLabels: { app: aifactory } }
  template:
    metadata: { labels: { app: aifactory } }
    spec:
      containers:
        - name: app
          image: ghcr.io/olafkfreund/aifactory:0.1.0
          ports: [ { containerPort: 8080 } ]
        - name: tailscale
          image: ghcr.io/tailscale/tailscale:v1.74.0
          env:
            - { name: TS_AUTHKEY, valueFrom: { secretKeyRef: { name: tailscale-auth-key, key: TS_AUTHKEY } } }
            - { name: TS_HOSTNAME, value: aifactory }
            - { name: TS_USERSPACE, value: "true" }
            - { name: TS_STATE_DIR, value: /tmp/tsstate }
EOF
cat > deploy/k8s/service.yaml <<'EOF'
apiVersion: v1
kind: Service
metadata:
  name: aifactory
  namespace: factory
spec:
  selector: { app: aifactory }
  ports: [ { port: 80, targetPort: 8080 } ]
EOF
git add deploy/k8s && git commit -m "feat(deploy): k8s manifests" && git push

# 2. In factory-gitops:
mkdir -p apps/aifactory
cat > apps/aifactory/application.yaml <<'EOF'
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: aifactory
  namespace: argocd
  finalizers: [resources-finalizer.argocd.argoproj.io]
spec:
  project: default
  source:
    repoURL: https://github.com/olafkfreund/AIFactory
    targetRevision: main
    path: deploy/k8s
  destination:
    server: https://kubernetes.default.svc
    namespace: factory
  syncPolicy:
    automated: { prune: true, selfHeal: true }
    syncOptions: [ CreateNamespace=true ]
EOF
git add apps/aifactory && git commit -m "feat(apps): add aifactory" && git push

# 3. Wait ~3 min, then:
curl -sI https://aifactory.tail833f7.ts.net
```

## Related

- Cluster ops: [k3d Cluster](../applications/k3d-cluster.md)
- Architecture: [k3d Architecture](../architecture/k3d-architecture.md)
- Tailscale sidecar reference: <https://tailscale.com/kb/1185/kubernetes>
- Tailscale auth keys: <https://tailscale.com/kb/1085/auth-keys>
- ArgoCD upstream: <https://argo-cd.readthedocs.io/>
