# Cloudflare Tunnel — Operator Runbook (Host Side)

The host-side Cloudflare Tunnel exposes services that live directly on
the homelab host (developer portal, media stack) to the public internet
under our home domain. For the cluster-side tunnel and overall design
rationale, see [Public Ingress Architecture](../architecture/public-ingress.md).

> Throughout this page, `<home-domain>` is our public domain;
> `<name>.<home-domain>` is one exposed service hostname;
> `<tunnel-id>` is a Cloudflare Tunnel UUID. We don't enumerate real
> values — the source of truth is the host's NixOS configuration
> and the agenix-encrypted credentials in `secrets/`.

## TL;DR

```bash
# Is it running?
ssh <host> systemctl is-active cloudflared-tunnel-<tunnel-id>

# Logs (most recent connections + ingress lookups)
ssh <host> sudo journalctl -u cloudflared-tunnel-<tunnel-id> -fb

# Quick health check on the public side
curl -sI https://<name>.<home-domain> | head -1
# expect HTTP/2 200 / 302 / 401 / 403 depending on the service
```

## What the module does

`modules/services/cloudflared.nix` is a thin feature-flag wrapper over
the upstream `services.cloudflared`. It pins one tunnel by UUID, points
the credentials and account-certificate paths at agenix secrets, and
declares an `ingress` map of `<hostname> → <local URL>` pairs.

```nix
features.cloudflared = {
  enable = true;
  tunnelId = "<tunnel-id>";
  ingress = {
    "<name1>.<home-domain>" = "http://localhost:<port>";
    "<name2>.<home-domain>" = "http://localhost:<port>";
    # ...
  };
};
```

The module then materialises a systemd unit named
`cloudflared-tunnel-<tunnel-id>.service`. The unit is `DynamicUser=true`,
loads credentials via systemd's `LoadCredential=`, and connects out
over QUIC to Cloudflare's edge. No inbound port is opened on the host.

## First-time bootstrap (~10 min, one-time)

Done already for the current tunnel. Repeat only if you're standing up
a new tunnel on a new host.

1. **Add the public domain as a Cloudflare zone** (free tier is enough).
   Switch the domain's nameservers at its registrar to the two values
   Cloudflare gives you. Wait for propagation (`dig NS <home-domain>` —
   should return Cloudflare NS values).
2. **On a workstation** with browser access (NOT the headless host):

   ```bash
   nix-shell -p cloudflared
   cloudflared login
   # → browser opens; choose the domain; saves ~/.cloudflared/cert.pem
   cloudflared tunnel create <name>
   # → prints the tunnel UUID; saves ~/.cloudflared/<uuid>.json
   ```

3. **Put both files into agenix**:

   ```bash
   ./scripts/manage-secrets.sh edit cloudflared-cert         # paste cert.pem contents
   ./scripts/manage-secrets.sh edit cloudflared-credentials  # paste credentials.json contents
   ```

4. **Wire the tunnel UUID + first route** in the host configuration
   (`features.cloudflared.tunnelId`, `ingress`), commit, deploy.
5. **Create the first Cloudflare DNS CNAME**:

   ```bash
   cloudflared tunnel route dns <name> <name>.<home-domain>
   ```

## Adding a new service (the common path)

1. Append a route to the host configuration's `features.cloudflared.ingress`
   attrset.
2. Commit, push, merge, deploy.
3. On the host (cert.pem is now decrypted into `/run/agenix/cloudflared-cert`),
   create the Cloudflare DNS CNAME:

   ```bash
   export TUNNEL_ORIGIN_CERT=/run/agenix/cloudflared-cert
   /run/current-system/sw/bin/cloudflared tunnel route dns \
     <tunnel-name> <name>.<home-domain>
   ```

   (or — same thing — run it from a workstation that has its own
   cert.pem.)
4. Smoke test:

   ```bash
   curl -sI --doh-url https://1.1.1.1/dns-query https://<name>.<home-domain> | head -1
   ```

   Anything other than `HTTP/2 5xx` is success (`200`, `302`, `401`,
   `403` all mean the request reached the service and the service
   responded — its own auth then takes over).

## Authentication note

Cloudflare Tunnel does **not** add an authentication layer. Whatever
auth the service ships with applies:

- The developer portal: GitHub OAuth (configured in its own
  app-config).
- The *arr stack (Sonarr, Radarr, Lidarr): API-key / session cookie.
  Their UIs return `401` until you set the API key in headers or log
  in.
- NZBGet / SABnzbd: control password from their respective config.
- Plex: a Plex token.

For services that ship no UI auth (or weak auth), gate at the
Cloudflare edge: **Cloudflare Zero Trust → Access → Applications** in
the dashboard. Free tier covers 50 users. Each Access policy is
scoped to one hostname and gates the connection before it reaches the
tunnel.

## Rotation

### Auth-key / credentials rotation

If `credentials.json` is ever compromised:

```bash
# On the workstation:
cloudflared tunnel delete <name>
cloudflared tunnel create <name>  # NEW UUID
# Re-route every existing DNS entry to the new UUID:
for HOST in <list of hostnames>; do
  cloudflared tunnel route dns <name> $HOST
done

# Refresh agenix secrets:
./scripts/manage-secrets.sh edit cloudflared-credentials

# Update tunnelId in host config to the new UUID, deploy.
```

### Account-cert (cert.pem) rotation

Same flow but starts with `cloudflared login` to re-issue cert.pem.
The cert.pem grants the ability to create new tunnels and route DNS
— it does NOT carry the per-tunnel connector credentials. Rotate
separately.

## Troubleshooting

### `curl` returns nothing / DNS lookup fails

Check the Cloudflare CNAME exists. From the host:

```bash
# Direct CF API check — needs the cert.pem
sudo TUNNEL_ORIGIN_CERT=/run/agenix/cloudflared-cert \
  /run/current-system/sw/bin/cloudflared tunnel route dns \
  <tunnel-name> <name>.<home-domain>
```

This is idempotent — running it on an existing record is a no-op that
prints the same `Added CNAME …` line. If you get an error about the
tunnel UUID or auth, the cert.pem is wrong or the tunnel doesn't
exist.

### `HTTP/2 502` from the public URL

The tunnel is healthy (we got an HTTP response from Cloudflare) but
cloudflared couldn't reach the origin service. Common causes:

1. Service binds to a non-loopback interface. Check the route in
   the module config — `http://localhost:<port>` only works if the
   service is bound to `127.0.0.1` or `0.0.0.0`. If the service
   binds to a LAN IP only, change the route to that IP.
2. Service is down. `systemctl status <service>` on the host.
3. Wrong port. Verify with `curl http://localhost:<port>` from the
   host.

### `HTTP/2 1033` — "Cloudflare Tunnel error"

Cloudflare's edge sees the DNS record but no connector is currently
registered. Either cloudflared isn't running on the host, or it can't
reach Cloudflare's edge:

```bash
systemctl status cloudflared-tunnel-<tunnel-id>
journalctl -u cloudflared-tunnel-<tunnel-id> -b --no-pager | tail -50
# Expect to see "Registered tunnel connection" lines.
```

### "redirect_uri is not associated with this application" — GitHub OAuth

Not a Cloudflare problem. The developer portal's GitHub OAuth App has
an outdated callback URL. Update it at
`github.com/settings/developers` → OAuth Apps → your portal app →
`https://<name>.<home-domain>/api/auth/github/handler/frame`.

### The service redirect-loops with `307 → 307 → …`

The service is trying to redirect HTTP to HTTPS at the application
layer, but cloudflared's loopback hop is plain HTTP. Either:

- Configure the service to trust `X-Forwarded-Proto: https` (most
  app servers have a `behind-proxy` toggle).
- Or terminate TLS inside the service and proxy via
  `https://localhost:<port>` from cloudflared (set
  `originRequest.noTLSVerify = true` to accept self-signed certs).

### Resetting a tunnel from scratch

If everything's broken and you just want a clean slate:

```bash
# Stop the unit
systemctl stop cloudflared-tunnel-<tunnel-id>

# On a workstation:
cloudflared tunnel delete <name> --force
cloudflared tunnel create <name>
# Re-route every DNS entry (loop above)
# Edit agenix creds, update tunnelId in host config, deploy
```

## What's NOT documented here

- **In-cluster** cloudflared (for the Factory suite / ArgoCD /
  Keycloak): same daemon, different deployment (Kubernetes Deployment
  in the `factory` namespace), different tunnel UUID. Its config
  lives in the `factory-gitops` repo under `infra/cloudflared/`.
  Adding a route there means a commit + ArgoCD sync, then the same
  DNS-route command. Cross-reference:
  [Public Ingress Architecture](../architecture/public-ingress.md).
- **Cloudflare Zero Trust access policies**: configured in the
  Cloudflare dashboard, not in code. Document them where the access
  policy itself lives (Cloudflare's UI) rather than duplicating
  here.

## Cross-references

- Architecture rationale: [Public Ingress Architecture](../architecture/public-ingress.md)
- Cluster-side tunnel + manifests location: [k3d Cluster Operations](k3d-cluster.md)
- GitOps workflow for adding a public cluster service: [Factory GitOps](../guides/factory-gitops.md)
