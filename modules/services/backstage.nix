# Backstage developer portal.
#
# Runs olafkfreund/backstage (a customised Spotify Backstage app) on p510
# alongside a sibling Postgres container. Image is consumed from
# ghcr.io/olafkfreund/backstage, pinned to a SHA digest (NEVER :latest —
# that's a supply-chain risk: a leaked GHCR token could quietly swap the
# running image).
#
# Wiring overview:
#
#   ┌─────────────────────────┐      ┌──────────────────────────┐
#   │ podman-backstage-postgres│◀────│ podman-backstage          │
#   │ 127.0.0.1:5435 → 5432   │      │ 127.0.0.1:7007 → 7007    │
#   └─────────────────────────┘      └──────────────────────────┘
#                                              ▲
#                                              │ Tailscale Serve
#                                              │ /backstage path
#                                              ▼
#                          https://p510.tail833f7.ts.net/backstage
#
# Secrets (from agenix, loaded at runtime — never in the Nix store):
#   backstage-postgres-password        → POSTGRES_PASSWORD
#   backstage-github-token             → GITHUB_TOKEN (catalog integration)
#   backstage-github-oauth-client-id   → AUTH_GITHUB_CLIENT_ID
#   backstage-github-oauth-client-secret → AUTH_GITHUB_CLIENT_SECRET
#
# The secret-to-env bridge: a one-shot systemd unit (backstage-env-setup)
# reads /run/agenix/backstage-* and writes /run/backstage/env-{postgres,
# backstage}, consumed by the container services as environmentFiles.
# /run/backstage is tmpfs (cleared on every boot — secrets re-emitted each
# time the unit runs).
#
# This module is intentionally disabled by default. Flip
# features.backstage.enable = true on p510 only AFTER:
#   1. Phase 1 image is in ghcr.io with a real SHA digest
#   2. Phase 2 agenix secrets exist and have been rekeyed
#   3. Phase 4 Tailscale Serve route is added
# See olafkfreund/nixos_config epic #731.

{ config, lib, pkgs, ... }:
let
  cfg = config.features.backstage;
  pgDataDir = "/var/lib/backstage-postgres";
  envDir = "/run/backstage";

  agenixPath = name: "/run/agenix/${name}";
in
{
  options.features.backstage = {
    enable = lib.mkEnableOption "Backstage developer portal";

    image = lib.mkOption {
      type = lib.types.str;
      default = "ghcr.io/olafkfreund/backstage@sha256:58af6263670b816da7ba0cb54c7449e11c6b3526ce9cdb652ee21f84fec92a33";
      example = "ghcr.io/olafkfreund/backstage@sha256:abc123...";
      description = ''
        OCI image to pull for the Backstage backend. MUST be pinned to a
        SHA256 digest (the @sha256:... form). Do NOT use :latest — updates
        should be explicit nixos commits so a leaked GHCR token can't
        quietly swap the running image.
      '';
    };

    postgresImage = lib.mkOption {
      type = lib.types.str;
      default = "docker.io/postgres:16-alpine";
      description = "OCI image for the Postgres sidecar.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 7007;
      description = "Localhost port the Backstage backend binds to.";
    };

    pgPort = lib.mkOption {
      type = lib.types.port;
      default = 5435;
      description = ''
        Localhost port for Backstage's Postgres. 5435 avoids colliding with
        skill-pool's 5434 on p620 (in case that ever migrates to p510) and
        with a typical host Postgres on 5432.
      '';
    };

    pgDatabase = lib.mkOption {
      type = lib.types.str;
      default = "backstage";
      description = "Postgres database name.";
    };

    pgUser = lib.mkOption {
      type = lib.types.str;
      default = "backstage";
      description = "Postgres user.";
    };

    publicUrl = lib.mkOption {
      type = lib.types.str;
      default = "https://p510.tail833f7.ts.net/backstage";
      description = ''
        Public-facing base URL Backstage uses for app.baseUrl,
        backend.baseUrl, CORS origin, and OAuth callbacks. If you rename
        your tailnet or move Backstage to a different host, update this
        AND the GitHub OAuth App's authorization callback URL (which
        must match exactly).
      '';
    };

    memoryHigh = lib.mkOption {
      type = lib.types.str;
      default = "2G";
      description = ''
        Soft memory cap on the Backstage container (passed as --memory to
        podman). Caps blast radius if Backstage leaks memory while Plex
        transcode + Ollama are running. Epic #731 risk #3.
      '';
    };
  };

  config = lib.mkIf cfg.enable {

    # ---------------------------------------------------------------------
    # Agenix secrets — runtime loading, never in the Nix store.
    # ---------------------------------------------------------------------
    age.secrets.backstage-github-token = {
      file = ../../secrets/backstage-github-token.age;
      mode = "0400";
    };
    age.secrets.backstage-github-oauth-client-id = {
      file = ../../secrets/backstage-github-oauth-client-id.age;
      mode = "0400";
    };
    age.secrets.backstage-github-oauth-client-secret = {
      file = ../../secrets/backstage-github-oauth-client-secret.age;
      mode = "0400";
    };
    age.secrets.backstage-postgres-password = {
      file = ../../secrets/backstage-postgres-password.age;
      mode = "0400";
    };
    age.secrets.backstage-gitlab-token = {
      file = ../../secrets/backstage-gitlab-token.age;
      mode = "0400";
    };
    age.secrets.backstage-mcp-token = {
      file = ../../secrets/backstage-mcp-token.age;
      mode = "0400";
    };
    age.secrets.backstage-github-webhook-secret = {
      file = ../../secrets/backstage-github-webhook-secret.age;
      mode = "0400";
    };

    # ---------------------------------------------------------------------
    # Persistent state.
    # ---------------------------------------------------------------------
    systemd.tmpfiles.rules = [
      # UID 70 is the postgres user inside the postgres:16-alpine image.
      # Don't use `root root` — systemd-tmpfiles-resetup re-applies
      # ownership on every activation, and a root-owned 0700 dir blocks
      # the in-container postgres user from traversing into its own
      # data files (`could not open file global/pg_filenode.map`).
      "d ${pgDataDir} 0700 70 70 - -"
      # /run is tmpfs and systemd-tmpfiles-clean periodically removes
      # undeclared paths under /run. Declare /run/backstage so it
      # survives activations + cleanups; env-setup re-emits files into it.
      "d ${envDir} 0700 root root - -"
      # TechDocs render cache (publisher=local). Mounted into the
      # backstage container at /tmp/techdocs so mkdocs build output
      # survives container restarts. Owned by uid 1000 (node user
      # inside the container).
      "d /var/lib/backstage-techdocs 0700 1000 1000 - -"
    ];

    # ---------------------------------------------------------------------
    # Secret-to-env bridge.
    #
    # Both container services consume environmentFiles. We assemble them at
    # runtime from the agenix-decrypted secrets so the values never appear
    # in the Nix store. /run/backstage is tmpfs (cleared each boot).
    # ---------------------------------------------------------------------
    systemd.services.backstage-env-setup = {
      description = "Assemble Backstage env files from agenix secrets";
      wantedBy = [ "multi-user.target" ];
      before = [
        "podman-backstage.service"
        "podman-backstage-postgres.service"
      ];
      # agenix populates /run/agenix/* during NixOS activation (before
      # systemd reaches multi-user.target), so no explicit ordering on an
      # agenix.service is needed — and indeed agenix isn't a systemd unit.

      serviceConfig = {
        Type = "oneshot";
        # NOT RemainAfterExit: we want this to re-run on every dependent
        # service start (e.g. after `systemctl restart podman-backstage`)
        # so the env files in /run/backstage are always fresh. Otherwise
        # systemd considers env-setup "active (exited) success" and skips
        # it, leaving podman to fail on missing env files after an
        # unrelated activation cleared /run/backstage/*.
      };

      script = ''
        set -euo pipefail
        umask 077
        mkdir -p ${envDir}

        PG_PASSWORD=$(cat ${agenixPath "backstage-postgres-password"})
        GH_TOKEN=$(cat ${agenixPath "backstage-github-token"})
        GH_OAUTH_ID=$(cat ${agenixPath "backstage-github-oauth-client-id"})
        GH_OAUTH_SECRET=$(cat ${agenixPath "backstage-github-oauth-client-secret"})
        GL_TOKEN=$(cat ${agenixPath "backstage-gitlab-token"})
        MCP_TOKEN=$(cat ${agenixPath "backstage-mcp-token"})
        GH_WEBHOOK_SECRET=$(cat ${agenixPath "backstage-github-webhook-secret"})

        cat > ${envDir}/env-postgres <<EOF
        POSTGRES_USER=${cfg.pgUser}
        POSTGRES_PASSWORD=$PG_PASSWORD
        POSTGRES_DB=${cfg.pgDatabase}
        EOF

        cat > ${envDir}/env-backstage <<EOF
        BACKSTAGE_PUBLIC_URL=${cfg.publicUrl}
        # Container-to-container DNS on the shared backstage-net podman
        # network — Postgres is reachable by container name, NOT via the
        # host's loopback port (which 127.0.0.1:5435 binds to but the
        # podman bridge gateway can't traverse).
        POSTGRES_HOST=backstage-postgres
        POSTGRES_PORT=5432
        POSTGRES_USER=${cfg.pgUser}
        POSTGRES_PASSWORD=$PG_PASSWORD
        POSTGRES_DB=${cfg.pgDatabase}
        GITHUB_TOKEN=$GH_TOKEN
        AUTH_GITHUB_CLIENT_ID=$GH_OAUTH_ID
        AUTH_GITHUB_CLIENT_SECRET=$GH_OAUTH_SECRET
        GITLAB_TOKEN=$GL_TOKEN
        MCP_TOKEN=$MCP_TOKEN
        GITHUB_WEBHOOK_SECRET=$GH_WEBHOOK_SECRET
        EOF

        chmod 0400 ${envDir}/env-postgres ${envDir}/env-backstage
      '';
    };

    # ---------------------------------------------------------------------
    # Containers.
    # ---------------------------------------------------------------------
    virtualisation.podman.enable = lib.mkDefault true;

    # Shared podman network so the backstage container can reach Postgres
    # by container name (DNS-resolved on the bridge). Created idempotently
    # before either container starts. `|| true` so re-runs don't fail.
    systemd.services.backstage-network = {
      description = "Create podman network for Backstage containers";
      wantedBy = [ "multi-user.target" ];
      before = [
        "podman-backstage.service"
        "podman-backstage-postgres.service"
      ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        ${pkgs.podman}/bin/podman network exists backstage-net \
          || ${pkgs.podman}/bin/podman network create backstage-net
      '';
    };

    virtualisation.oci-containers = {
      backend = lib.mkDefault "podman";

      containers."backstage-postgres" = {
        image = cfg.postgresImage;
        # No host port mapping — Postgres is only consumed by the sibling
        # backstage container via the shared backstage-net network. Keeps
        # postgres entirely off the host's port table.
        environmentFiles = [ "${envDir}/env-postgres" ];
        volumes = [ "${pgDataDir}:/var/lib/postgresql/data" ];
        autoStart = true;
        extraOptions = [ "--network=backstage-net" ];
      };

      containers."backstage" = {
        image = cfg.image;
        ports = [ "127.0.0.1:${toString cfg.port}:7007" ];
        environmentFiles = [ "${envDir}/env-backstage" ];
        dependsOn = [ "backstage-postgres" ];
        autoStart = true;
        # /var/lib/backstage-techdocs persists the rendered MkDocs output
        # (publisher=local) across container restarts.
        volumes = [ "/var/lib/backstage-techdocs:/tmp/techdocs" ];
        extraOptions = [
          "--network=backstage-net"
          "--memory=${cfg.memoryHigh}"
        ];
      };
    };

    # Chain the container units onto env-setup + network creation so they
    # don't race on cold boot.
    systemd.services.podman-backstage-postgres = {
      after = [ "backstage-env-setup.service" "backstage-network.service" ];
      requires = [ "backstage-env-setup.service" "backstage-network.service" ];
    };
    systemd.services.podman-backstage = {
      after = [
        "backstage-env-setup.service"
        "backstage-network.service"
        "podman-backstage-postgres.service"
      ];
      requires = [ "backstage-env-setup.service" "backstage-network.service" ];
    };
  };
}
