# Backstage on p510

Operator-facing reference for the Backstage developer portal running on
**p510**. Module source: `modules/services/backstage.nix`. App source:
[`olafkfreund/backstage`](https://github.com/olafkfreund/backstage).
Tracking epic: [#731](https://github.com/olafkfreund/nixos_config/issues/731).

## Overview

Backstage is Spotify's open-source developer portal — catalog of services,
TechDocs, software templates, plugin ecosystem. We run it as our home-lab
single-pane-of-glass for cataloguing infrastructure, services, and
runbooks.

### Architecture

```text
                                 https://p510.tail833f7.ts.net/backstage
                                                ▲
                                                │  Tailscale Serve
                                                │  (HTTPS terminates here)
                                                ▼
              ┌────────────────────────────────────────────┐
              │ p510                                       │
              │                                            │
              │ ┌──────────────────┐   ┌────────────────┐ │
              │ │ podman-backstage │──▶│ podman-        │ │
              │ │ :7007 (lo)       │   │ backstage-     │ │
              │ │ ghcr.io image,   │   │ postgres       │ │
              │ │ SHA-pinned       │   │ :5435 (lo)     │ │
              │ └────────▲─────────┘   └────────────────┘ │
              │          │                                │
              │ ┌────────┴─────────┐                      │
              │ │ backstage-env-   │                      │
              │ │ setup oneshot:   │                      │
              │ │ agenix →         │                      │
              │ │ /run/backstage/  │                      │
              │ └──────────────────┘                      │
              └────────────────────────────────────────────┘
```

- **Image**: built from `olafkfreund/backstage` by GitHub Actions, pushed
  to `ghcr.io/olafkfreund/backstage`, pinned by SHA digest in
  `features.backstage.image`. NEVER `:latest`.
- **Postgres**: sibling podman container, localhost-only, volume at
  `/var/lib/backstage-postgres`. Not exposed off p510.
- **Secrets**: agenix-encrypted, runtime-loaded into `/run/backstage/env-*`
  by a one-shot systemd unit, never in the Nix store.
- **Exposure**: Tailscale Serve path `/backstage` → `localhost:7007`. TLS
  by Tailscale; no nginx, no Let's Encrypt to manage.
- **Auth**: GitHub OAuth primary, guest fallback for read-only catalog
  browsing.

## Module reference (`features.backstage.*`)

| Option | Type | Default | Purpose |
|---|---|---|---|
| `enable` | bool | `false` | Master switch. |
| `image` | str | `ghcr.io/olafkfreund/backstage@sha256:49f4e8e...` | SHA-pinned image. Bump by editing this string. |
| `postgresImage` | str | `docker.io/postgres:16-alpine` | Postgres sidecar. |
| `port` | port | `7007` | Localhost backend port. |
| `pgPort` | port | `5435` | Localhost Postgres port (avoids skill-pool's 5434). |
| `pgDatabase` | str | `backstage` | Database name. |
| `pgUser` | str | `backstage` | Postgres user. |
| `publicUrl` | str | `https://p510.tail833f7.ts.net/backstage` | Used for `app.baseUrl`, CORS, OAuth callback origin. Must match the GitHub OAuth App's callback URL. |
| `memoryHigh` | str | `2G` | Container `--memory` cap. |

## First-time deploy procedure (epic gate)

This module is disabled by default. To enable it, all of the following
must already be true:

1. **Phase 1 image exists** — `olafkfreund/backstage` has a green CI run
   and an image is published to `ghcr.io/olafkfreund/backstage`. Capture
   the SHA digest from the workflow's "Print SHA digest" step.
2. **Phase 2 agenix secrets exist** — these four `.age` files are present
   in `secrets/` and registered in `secrets/secrets.nix`:
   - `backstage-postgres-password.age`
   - `backstage-github-token.age` (fine-grained PAT, NOT classic)
   - `backstage-github-oauth-client-id.age`
   - `backstage-github-oauth-client-secret.age`
   And `./scripts/manage-secrets.sh rekey` has been run.
3. **Phase 2 GitHub OAuth App exists** — registered at
   <https://github.com/settings/applications/new> with callback URL
   matching `features.backstage.publicUrl` exactly.
4. **Phase 4 Tailscale Serve route exists** — `/backstage` →
   `localhost:7007` in `hosts/p510/nixos/tailscale-serve.nix`.

Then on p510 in `hosts/p510/configuration.nix`:

```nix
features.backstage = {
  enable = true;
  image = "ghcr.io/olafkfreund/backstage@sha256:<paste-from-CI>";
};
```

`just test-host p510` → `just quick-deploy p510`.

## Verification

```bash
# On p510
sudo podman ps                                    # both containers Up
sudo systemctl status backstage-env-setup         # active (exited), no errors
curl -sf http://localhost:7007/healthcheck        # 200 OK
curl -sf http://localhost:7007/api/catalog/entities | jq '. | length'

# From dev laptop
curl -sf https://p510.tail833f7.ts.net/backstage/healthcheck
open https://p510.tail833f7.ts.net/backstage
```

## Operations runbook

### Logs

```bash
sudo journalctl -u podman-backstage -f
sudo journalctl -u podman-backstage-postgres -f
sudo journalctl -u backstage-env-setup -n 50
```

### Where data lives

- Postgres volume: `/var/lib/backstage-postgres` (root-owned, container UID
  inside)
- Env files (runtime, tmpfs): `/run/backstage/env-postgres`,
  `/run/backstage/env-backstage`
- Decrypted agenix secrets: `/run/agenix/backstage-*` (mode 0400, root)

### Restart

```bash
sudo systemctl restart podman-backstage
# If you suspect env-file desync, force a re-emit:
sudo systemctl restart backstage-env-setup
sudo systemctl restart podman-backstage
```

### Emergency disable

```nix
# hosts/p510/configuration.nix
features.backstage.enable = false;
```

`just quick-deploy p510`. The containers are stopped and removed; Postgres
data persists in the volume.

## Upgrade procedure

1. **In `olafkfreund/backstage`**: `yarn backstage-cli versions:bump`,
   resolve any breaking changes (read upstream release notes for major
   bumps), `yarn dev` to verify locally
2. Commit, push, wait for the green CI run
3. Copy the new SHA digest from the workflow output
4. **In this repo**: edit `hosts/p510/configuration.nix`, replace the
   `features.backstage.image` digest
5. `just test-host p510` (build only)
6. `just quick-deploy p510`
7. Verify with the section above

### Rollback

NixOS makes this cheap:

```bash
sudo nixos-rebuild switch --rollback
```

Or revert the digest commit and redeploy. The previous image stays in
local podman storage AND on ghcr.io (tagged by its commit SHA).

## Adding a catalog entity

Drop a `catalog-info.yaml` in any GitHub repo Backstage's PAT can read:

```yaml
apiVersion: backstage.io/v1alpha1
kind: Component
metadata:
  name: my-service
  description: Short description
  annotations:
    github.com/project-slug: owner/repo
spec:
  type: service
  lifecycle: production
  owner: olafkfreund
```

Then in Backstage UI: **Create** → **Register existing component** →
paste the GitHub URL to `catalog-info.yaml` → submit.

For auto-discovery across an org, add a Location of type `url` in
`app-config.production.yaml` pointing to the org's discovery endpoint.

See <https://backstage.io/docs/features/software-catalog/descriptor-format>
for all fields.

## Adding a plugin

Plugin add/upgrade lives in the app repo. See
[`olafkfreund/backstage/docs/PLUGINS.md`](https://github.com/olafkfreund/backstage/blob/main/docs/PLUGINS.md).
After landing a plugin and CI publishing the new image, bump the digest in
this repo per the Upgrade procedure above.

## Secret rotation

### Fine-grained PAT (annual)

1. Issue a new fine-grained PAT at
   <https://github.com/settings/personal-access-tokens>
2. `./scripts/manage-secrets.sh edit backstage-github-token`
3. `./scripts/manage-secrets.sh rekey`
4. `just quick-deploy p510`
5. Revoke the old PAT after verifying the catalog still syncs

### OAuth client secret (rotate if suspected compromise)

1. Regenerate the client secret at <https://github.com/settings/developers>
   (Backstage OAuth App → "Generate a new client secret")
2. `./scripts/manage-secrets.sh edit backstage-github-oauth-client-secret`
3. `./scripts/manage-secrets.sh rekey`
4. `just quick-deploy p510`

### Postgres password

Risky — current data is encrypted with the running password. Simplest path
is the **full reset** below if the catalog is small.

Cleaner path:

```bash
# On p510, inside the container:
sudo podman exec -it backstage-postgres psql -U backstage \
  -c "ALTER USER backstage WITH PASSWORD 'new-password';"
```

Then `./scripts/manage-secrets.sh edit backstage-postgres-password` to
update agenix, rekey, redeploy.

## Disaster recovery

### What's where, what's recoverable

| Data | Location | Recoverable? |
|---|---|---|
| Catalog metadata (entity registrations) | Postgres | Yes — re-discovered from `catalog-info.yaml` files in your repos |
| User-added annotations | Postgres | **No backup yet** (see below) |
| TechDocs metadata (when enabled) | Postgres | Re-built from source |
| Auth sessions | Postgres | Trivial — re-login |
| `catalog-info.yaml` source | GitHub repos | Yes (git) |

### Backups (not yet configured — deferred to v2)

Recipe to add later:

```nix
# In modules/services/backstage.nix once enabled
systemd.services.backstage-postgres-backup = {
  startAt = "Mon 03:00";
  serviceConfig.Type = "oneshot";
  script = ''
    ${pkgs.podman}/bin/podman exec backstage-postgres \
      pg_dump -U backstage backstage \
      | ${pkgs.gzip}/bin/gzip > /var/backups/backstage-$(date +%F).sql.gz
    find /var/backups -name 'backstage-*.sql.gz' -mtime +28 -delete
  '';
};
```

Tracked in epic #731 risk #6.

### Full reset (nuclear)

```bash
# On p510
sudo systemctl stop podman-backstage podman-backstage-postgres
sudo rm -rf /var/lib/backstage-postgres
sudo systemctl start podman-backstage-postgres podman-backstage
# Backstage re-initialises the schema and re-discovers catalog entities
# from catalog-info.yaml files in your repos.
```

## Known limitations / out of scope

- **TechDocs** not enabled (needs storage backend)
- **Kubernetes plugin** not enabled (no live cluster on the freundcloud
  network)
- **Software templates / scaffolder backend** not wired up
- **No backup** of Postgres (see above)
- **OAuth callback URL coupled to tailnet hostname** — if you ever rename
  your tailnet or move Backstage to a different host, both
  `features.backstage.publicUrl` AND the GitHub OAuth App's callback URL
  must be updated. Cross-ref epic #731 risk #9.

## Troubleshooting

### Tailscale Serve returns 502

Container isn't running. `sudo podman ps`; if missing, check
`journalctl -u podman-backstage -n 100` for the start error.

### "Authentication failed" after GitHub login

OAuth callback URL mismatch. Check that `features.backstage.publicUrl`
ends with no trailing slash AND that the GitHub OAuth App's "Authorization
callback URL" is `<publicUrl>/api/auth/github/handler/frame` exactly.

### Container OOM-killed during Plex transcode

`features.backstage.memoryHigh` is the cap. If it's hitting it, either
raise the cap or add Backstage to earlyoom's `--prefer` list so Plex wins
contention.

### Postgres won't start after a host postgres bump

Check `/var/lib/backstage-postgres/PG_VERSION` against the major version
in `features.backstage.postgresImage`. A `postgres:17-alpine` image
refuses to open a `PG_VERSION=16` data dir. Either pin the old image or
run `pg_upgrade` (out of scope here).

### `backstage-env-setup` failed

Means at least one agenix secret didn't decrypt. Run
`sudo ls -la /run/agenix/backstage-*` and
`sudo journalctl -u agenix -n 50`. Almost always: a botched rekey or a
missing host key for p510 in `secrets/secrets.nix`.
