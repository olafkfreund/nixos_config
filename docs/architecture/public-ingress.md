# Public Ingress Architecture

How services on the homelab become reachable from the public internet
without a public IP, without port forwards, and without a per-service
VPN identity that drifts every time a Pod restarts.

> Throughout this page, `<home-domain>` stands in for the public domain
> hosting our service hostnames, and `<name>.<home-domain>` is a single
> service hostname (e.g. `argocd.<home-domain>`, `aifactory.<home-domain>`).
> We don't enumerate the real hostnames in public docs — see
> [TechDocs hostname policy](#hostname-policy) at the bottom.

## The constraint we had to design around

The host that fronts most home-lab services sits behind **Starlink CGNAT**.
There is no public IPv4. There is no inbound port. Anything reaching that
host from "the internet" must come through a service that owns a public IP
and tunnels traffic to us.

That single constraint disqualifies:

- Port forwarding on the router
- A records pointing at the home IP
- Any DNS-only solution

It does NOT disqualify anything that uses an **outbound persistent
connection** from the host to a relay or edge. Most modern ingress
solutions are that shape.

## The choice: Cloudflare Tunnel

We use **two `cloudflared` connectors**, both outbound-only, both
declarative:

1. **Host-level connector** — a NixOS systemd service on the homelab
   host. Routes a curated list of hostnames to local processes:
   `<name>.<home-domain>` → `http://localhost:<port>`. Used for
   services running directly on the host (developer portal, media
   stack).
2. **In-cluster connector** — a Kubernetes Deployment in the
   single-node k3d cluster on the same host. Routes hostnames to
   in-cluster Services by their FQDN
   (`<svc>.<ns>.svc.cluster.local:<port>`). Used for everything that
   lives inside the cluster (Factory suite, ArgoCD, Keycloak).

Each connector dials Cloudflare's edge over outbound QUIC/HTTPS and
sits there waiting for inbound requests. Cloudflare's edge handles TLS
termination with a real Let's Encrypt cert for our domain, optionally
adds a Zero Trust access layer, and forwards the request bytes through
the established connection.

```text
                 ┌──── public internet ────────────────────────────┐
                 │                                                 │
  user browser →   <name>.<home-domain>                            │
                                ↓ DNS → Cloudflare anycast IP      │
                          TLS terminated at Cloudflare edge        │
                                ↓                                  │
                      outbound QUIC tunnel                         │
                 │                                                 │
                 └─────────────────┬───────────────────────────────┘
                                   │
            ┌──────────────────────┴─────────────────────────────┐
            │ homelab host (behind Starlink CGNAT)                │
            │                                                     │
            │  host-cloudflared (systemd)                         │
            │     <name>.<home-domain> → http://localhost:<port>  │
            │                                                     │
            │  ┌────────── k3d cluster ──────────────┐             │
            │  │  in-cluster cloudflared (Pod)       │             │
            │  │     <name>.<home-domain>            │             │
            │  │       → http://<svc>.<ns>.svc:<p>   │             │
            │  └─────────────────────────────────────┘             │
            └─────────────────────────────────────────────────────┘
```

Two tunnels rather than one is deliberate — each connector keeps its own
config close to the services it routes for. The host-side tunnel changes
when we add a host-level service (commit, deploy). The cluster-side
tunnel changes when we add a Pod (commit, ArgoCD syncs). Neither requires
touching the other.

## Why not the Tailscale Kubernetes Operator (with OAuth)

It is a great fit, in principle. It would auto-provision a tailnet
identity per Service via an annotation, hand back per-service
hostnames, and rotate identities cleanly. **We didn't go that direction
because:**

- The operator requires an OAuth client (a separate object in the
  Tailscale admin from a normal auth key) with the right scopes and
  tag ownership configured up front. The friction of generating that
  delayed the build.
- All exposed hostnames would live under our tailnet's `*.ts.net` suffix.
  Browsers wouldn't see our own brand. For an external-facing portal we
  want our own domain on the URL bar.
- Tailscale Funnel — the official "expose a tailnet service to the public
  internet" path — caps at **3 services on the free tier**. Beyond that
  it requires an upgrade. We needed nearer to twenty hostnames.

## Why not the Tailscale **sidecar** pattern (the path we tried)

The sidecar pattern looks identical to the operator from a YAML
standpoint: a `tailscale` container in each Pod, environment variable
`TS_HOSTNAME` set, an auth key in a Secret. It works with a plain
auth key, no OAuth required. So we built it first.

It bit us **three times**:

1. **Identity suffixes on restart.** Every Pod restart caused tailscaled
   inside the sidecar to register a fresh tailnet identity (because
   `TS_STATE_DIR=/tmp/...` was ephemeral). The Tailscale control plane
   won't return the old hostname when a new node key arrives — it appends
   a numeric suffix. So `argocd` became `argocd-1`, then `argocd-2`, and
   DNS for the canonical name kept pointing at the dead original device.
   We mitigated by adding a PersistentVolumeClaim for the state dir, but
   it left the cluster recreate path still vulnerable.
2. **Cached node key after admin deletion.** When we manually deleted the
   stale device entries from the Tailscale admin to clean up, the live
   sidecar still had a cached node key for the deleted node and stayed
   stuck in an infinite `PollNetMap: 404 node not found` retry loop. No
   auto-recovery. Manual state wipe required.
3. **Per-Pod boilerplate.** Every Deployment that wanted exposure
   needed the sidecar container, its env-from-Secret, its volumeMount,
   plus a separate ConfigMap holding the Tailscale Serve config that
   bridges the sidecar to the app container. ~20 lines per service,
   replicated everywhere.

The fragility class for (1) and (2) was the real driver. A Tuesday-night
"why is ArgoCD down again" became a debugging exercise that touched
agenix, PVC contents, the tailscale admin console, and `kubectl exec`s
into the sidecar. Cloudflare Tunnel makes none of that exist.

## Decision matrix

| Concern | Sidecar + auth key (rejected) | Tailscale Operator + OAuth (rejected) | Tailscale Funnel (rejected) | **Cloudflare Tunnel (chosen)** |
|---|---|---|---|---|
| Works behind CGNAT | ✅ | ✅ | ✅ | ✅ |
| No port forward needed | ✅ | ✅ | ✅ | ✅ |
| Custom domain in URL bar | ❌ | ❌ | ❌ | ✅ |
| Real Let's Encrypt cert | ❌ (tailnet cert) | ❌ (tailnet cert) | ❌ (tailnet cert) | ✅ |
| Stable hostname on Pod restart | ❌ unless PVC + lucky | ✅ | ✅ | ✅ |
| Stable hostname on admin delete | ❌ | ✅ | ✅ | ✅ |
| Per-service boilerplate | High | Low | Low | Low |
| Service cap (free tier) | None | None | 3 | None |
| Public-internet ready by default | No (tailnet only) | No (tailnet only) | Yes | Yes |
| Optional auth gate | Tailscale ACL | Tailscale ACL | Tailscale ACL | Cloudflare Access (Zero Trust) |
| Cost | Free | Free | Free up to 3 svc | Free |
| Setup complexity | Medium | Medium-high (OAuth) | Low | Low-medium (DNS migration) |

## Trade-offs we accept

Cloudflare is now in our public-traffic path. Specifically:

- **TLS terminates at Cloudflare's edge.** Cloudflare can see the
  plaintext of every request to a service exposed this way. For
  authenticated SaaS-style services we're comfortable with that;
  it's no different from any other CDN. Anything genuinely
  sensitive stays on tailnet-only addressing.
- **Cloudflare gets to choose to drop us.** A free-tier homelab is
  not their priority customer. If they ever decide tunnel usage
  needs to be paid, or our use looks like abuse to their automated
  systems, we lose ingress until we migrate. Mitigation: every
  service is also reachable on the tailnet for admins, so the
  failure mode is "public goes down, admins keep working" rather
  than total outage.
- **DNS authority moves to Cloudflare for the public domain.** The
  registrar stays where it was; only authoritative DNS moves. This
  is reversible by switching the registrar's NS records back.

## Adding a new public hostname

Two-step regardless of which tunnel you target.

### Host-level service (running directly on the host)

1. Append one line to the host config's cloudflared ingress block:

   ```nix
   "<name>.<home-domain>" = "http://localhost:<port>";
   ```

2. Deploy. Run the DNS-route command (one-off, from a place that has
   the agenix-decrypted cert.pem) to create the Cloudflare CNAME for
   the new hostname.

### Cluster service

1. Append one entry to the in-cluster cloudflared ConfigMap (managed in
   the GitOps repo's `infra/cloudflared/`):

   ```yaml
   - hostname: <name>.<home-domain>
     service: http://<svc>.<ns>.svc.cluster.local:<port>
   ```

2. Commit. ArgoCD syncs in ~3 minutes. Run the DNS-route command for
   the new hostname.

In both cases the new hostname returns service traffic within minutes,
behind a real TLS cert, with no further wiring.

## Migration state (as of this commit)

| Layer | State |
|---|---|
| Host services exposed via host-cloudflared | ✅ active for developer portal and media stack |
| Cluster services exposed via in-cluster cloudflared | ✅ active for Factory suite + ArgoCD + Keycloak |
| Old per-Pod Tailscale sidecars | ⚠️ still present on `argocd-server`; decommission queued |
| Old host-level `tailscale serve` route to developer portal | ⚠️ still wired in NixOS; decommission queued |
| Cluster route to `Keycloak` for OIDC use | ⏳ Keycloak is reachable; Factory pods are not yet wired to it (no `OIDC_*` env vars) |

## Hostname policy

We deliberately do **not** spell out the full DNS names of services in
public-facing documentation, including this TechDocs site (which is
itself public via GitHub Pages and the Backstage portal). The reason
is asymmetric: an attacker who knows the exact hostname can probe it;
a legitimate user already has a bookmark or a sidebar link.

The pattern in this doc set:

- `<home-domain>` — the public domain we host services under
- `<name>.<home-domain>` — a single service hostname
- `<tunnel-id>` — a Cloudflare Tunnel UUID (never a real value)

Source-controlled files that DO have to contain real hostnames
(NixOS module values, GitOps manifests) are the source of truth. The
`hosts/p510/configuration.nix` host config and the `factory-gitops`
repo are public, so even there we accept the leak; but we don't go
out of our way to enumerate the list anywhere a search engine will
crawl.

## Cross-references

- Cloudflared host module operations: [Cloudflared Tunnel](../applications/cloudflared-tunnel.md)
- k3d cluster architecture (where the in-cluster tunnel lives): [k3d Architecture](k3d-architecture.md)
- How a new service joins the cluster + becomes publicly reachable: [Factory GitOps](../guides/factory-gitops.md)
