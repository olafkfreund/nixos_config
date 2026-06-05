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

{ config, lib, ... }:
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
      default = "ghcr.io/olafkfreund/backstage@sha256:e0284ab7d1d119ae96c32949a982618a5e137a92cd741f786a696f1122a2f888";
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

    # ---------------------------------------------------------------------
    # Persistent state.
    # ---------------------------------------------------------------------
    systemd.tmpfiles.rules = [
      "d ${pgDataDir} 0700 root root - -"
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
      after = [ "agenix.service" ];
      requires = [ "agenix.service" ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };

      script = ''
        set -euo pipefail
        umask 077
        mkdir -p ${envDir}

        PG_PASSWORD=$(cat ${agenixPath "backstage-postgres-password"})
        GH_TOKEN=$(cat ${agenixPath "backstage-github-token"})
        GH_OAUTH_ID=$(cat ${agenixPath "backstage-github-oauth-client-id"})
        GH_OAUTH_SECRET=$(cat ${agenixPath "backstage-github-oauth-client-secret"})

        cat > ${envDir}/env-postgres <<EOF
        POSTGRES_USER=${cfg.pgUser}
        POSTGRES_PASSWORD=$PG_PASSWORD
        POSTGRES_DB=${cfg.pgDatabase}
        EOF

        cat > ${envDir}/env-backstage <<EOF
        BACKSTAGE_PUBLIC_URL=${cfg.publicUrl}
        POSTGRES_HOST=host.containers.internal
        POSTGRES_PORT=${toString cfg.pgPort}
        POSTGRES_USER=${cfg.pgUser}
        POSTGRES_PASSWORD=$PG_PASSWORD
        POSTGRES_DB=${cfg.pgDatabase}
        GITHUB_TOKEN=$GH_TOKEN
        AUTH_GITHUB_CLIENT_ID=$GH_OAUTH_ID
        AUTH_GITHUB_CLIENT_SECRET=$GH_OAUTH_SECRET
        EOF

        chmod 0400 ${envDir}/env-postgres ${envDir}/env-backstage
      '';
    };

    # ---------------------------------------------------------------------
    # Containers.
    # ---------------------------------------------------------------------
    virtualisation.podman.enable = lib.mkDefault true;

    virtualisation.oci-containers = {
      backend = lib.mkDefault "podman";

      containers."backstage-postgres" = {
        image = cfg.postgresImage;
        ports = [ "127.0.0.1:${toString cfg.pgPort}:5432" ];
        environmentFiles = [ "${envDir}/env-postgres" ];
        volumes = [ "${pgDataDir}:/var/lib/postgresql/data" ];
        autoStart = true;
      };

      containers."backstage" = {
        image = cfg.image;
        ports = [ "127.0.0.1:${toString cfg.port}:7007" ];
        environmentFiles = [ "${envDir}/env-backstage" ];
        dependsOn = [ "backstage-postgres" ];
        autoStart = true;
        # Soft memory cap — see options.memoryHigh.
        extraOptions = [ "--memory=${cfg.memoryHigh}" ];
      };
    };

    # Chain the container units onto our env-setup so they don't race the
    # agenix → /run/backstage emission on cold boot.
    systemd.services.podman-backstage-postgres = {
      after = [ "backstage-env-setup.service" ];
      requires = [ "backstage-env-setup.service" ];
    };
    systemd.services.podman-backstage = {
      after = [ "backstage-env-setup.service" "podman-backstage-postgres.service" ];
      requires = [ "backstage-env-setup.service" ];
    };
  };
}
