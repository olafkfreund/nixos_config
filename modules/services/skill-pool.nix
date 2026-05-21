# skill-pool — local-machine deployment of the registry portal.
#
# Single-node setup on p620:
#   - pgvector pg17 in a rootful podman container on 127.0.0.1:5433
#     (kept off the host's existing pg17 on 5432).
#   - skill-pool-server (HTTP API) on 127.0.0.1:8080 via the upstream
#     `nixosModules.skill-pool-server` module.
#   - skill-pool-web (SvelteKit adapter-node bundle) on 127.0.0.1:3030
#     via a custom systemd unit (the upstream module is server-only).
#   - First-boot bootstrap unit generates an admin token into
#     /var/lib/skill-pool/env (mode 0600, owned by skillpool).
#
# Secrets handling is dev-only on purpose: the postgres password is in
# the Nix store (world-readable) and the admin token is generated once at
# first boot. For any deploy that leaves this machine, route these through
# agenix (modules/security/secrets.nix already wires it).

{ lib, pkgs, inputs, ... }:

let
  system = pkgs.stdenv.hostPlatform.system;
  serverPkg = inputs.skill-pool.packages.${system}.skill-pool-server;
  cliPkg = inputs.skill-pool.packages.${system}.skill-pool-cli;
  webPkg = inputs.skill-pool.packages.${system}.skill-pool-web;

  pgPassword = "skillpool-dev-local";
  # 5433 collides with an unrelated skillai-db-1 docker container on this box.
  pgPort = 5434;
  serverPort = 8080;
  webPort = 3030;

  databaseUrl =
    "postgres://skillpool:${pgPassword}@127.0.0.1:${toString pgPort}/skillpool";
in
{
  imports = [ inputs.skill-pool.nixosModules.skill-pool-server ];

  # Make the admin (`skill-pool-server admin …`) and end-user (`skill-pool …`)
  # binaries reachable on the system PATH so tenant bootstrap commands and
  # local publishing both Just Work without hard-coded /nix/store paths.
  environment.systemPackages = [ serverPkg cliPkg ];

  # ---------------------------------------------------------------------------
  # 1. pgvector pg17 in a podman container, isolated from the host pg17.
  # ---------------------------------------------------------------------------

  virtualisation.podman.enable = lib.mkDefault true;

  virtualisation.oci-containers = {
    backend = "podman";

    containers."skill-pool-postgres" = {
      image = "docker.io/pgvector/pgvector:pg17";
      ports = [ "127.0.0.1:${toString pgPort}:5432" ];
      environment = {
        POSTGRES_USER = "skillpool";
        POSTGRES_PASSWORD = pgPassword;
        POSTGRES_DB = "skillpool";
      };
      volumes = [ "/var/lib/skill-pool-postgres:/var/lib/postgresql/data" ];
      autoStart = true;
      cmd = [ "postgres" ];
    };
  };

  systemd.tmpfiles.rules = [
    "d /var/lib/skill-pool-postgres 0700 root root - -"
  ];

  # ---------------------------------------------------------------------------
  # 2. skill-pool-server (HTTP API) on 127.0.0.1:8080.
  # ---------------------------------------------------------------------------

  services.skill-pool-server = {
    enable = true;
    package = serverPkg;
    bind = "127.0.0.1:${toString serverPort}";
    databaseUrl = databaseUrl;
    storageUri = "fs:///var/lib/skill-pool/bundles";
    defaultTenant = "acme";
    logLevel = "info,skill_pool=info";
    logFormat = "pretty";
    environmentFile = "/var/lib/skill-pool/env";
    openFirewall = false;
  };

  # Make the server wait for the pg container's unit before launching.
  # Connect-retries handle the brief "container up, postgres still
  # initializing" window — Restart=on-failure + RestartSec=5s in the
  # upstream module loops the server back to start.
  systemd.services.skill-pool-server = {
    after = lib.mkAfter [ "podman-skill-pool-postgres.service" ];
    requires = [ "podman-skill-pool-postgres.service" ];
  };

  # First-boot env-file bootstrap. Idempotent: only writes if missing.
  systemd.services.skill-pool-bootstrap = {
    description = "skill-pool first-boot env-file bootstrap";
    wantedBy = [ "skill-pool-server.service" ];
    before = [ "skill-pool-server.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      set -euo pipefail
      mkdir -p /var/lib/skill-pool
      if [ ! -f /var/lib/skill-pool/env ]; then
        umask 077
        TOKEN=$(${pkgs.openssl}/bin/openssl rand -hex 32)
        printf 'SKILL_POOL_ADMIN_TOKEN=%s\n' "$TOKEN" > /var/lib/skill-pool/env
        chown skillpool:skillpool /var/lib/skill-pool/env
        chmod 0600 /var/lib/skill-pool/env
      fi
    '';
  };

  # ---------------------------------------------------------------------------
  # 3. skill-pool-web (SvelteKit adapter-node bundle) on 127.0.0.1:3030.
  # ---------------------------------------------------------------------------

  systemd.services.skill-pool-web = {
    description = "skill-pool SvelteKit portal (adapter-node bundle)";
    wantedBy = [ "multi-user.target" ];
    after = [ "skill-pool-server.service" ];
    wants = [ "skill-pool-server.service" ];

    environment = {
      PORT = toString webPort;
      HOST = "127.0.0.1";
      ORIGIN = "http://localhost:${toString webPort}";
      SKILL_POOL_API_BASE = "http://127.0.0.1:${toString serverPort}";
      SP_DEFAULT_TENANT = "acme";
      NODE_ENV = "production";
    };

    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.nodejs_22}/bin/node ${webPkg}/index.js";
      Restart = "on-failure";
      RestartSec = "5s";

      DynamicUser = true;
      StateDirectory = "skill-pool-web";

      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      PrivateDevices = true;
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectControlGroups = true;
      ProtectClock = true;
      ProtectHostname = true;
      ProtectKernelLogs = true;
      RestrictSUIDSGID = true;
      RestrictRealtime = true;
      RestrictNamespaces = true;
      LockPersonality = true;
      SystemCallArchitectures = "native";
      RestrictAddressFamilies = [ "AF_INET" "AF_INET6" "AF_UNIX" ];
      MemoryMax = "512M";
      TasksMax = 256;
    };
  };
}
