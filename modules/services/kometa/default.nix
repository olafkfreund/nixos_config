# Kometa (was Plex Meta Manager) — collections + metadata + posters for Plex.
#
# Runs as a podman OCI container on p510 sharing the host network namespace
# so it can reach localhost:32400 (Plex) directly. Container is always-on;
# Kometa's internal scheduler fires per the `schedule:` key in config.yml.
#
# Phase 1a (this commit): dry-run mode + IMDb Top 250 only. Container will
# happily fail TMDB auth on first runs until you fill in the real key:
#   agenix -e secrets/kometa-env.age   # replace REPLACE_ME with real key
#   sudo systemctl restart podman-kometa.service
# Then watch /var/lib/kometa/logs/meta.log for the dry-run report.
#
# Phase 1b: once the dry-run output looks right, flip `dry_run: false` in
# modules/services/kometa/config.yml and redeploy.
#
# Pattern mirrors modules/services/skill-pool.nix (oci-containers + podman).
{ config
, lib
, pkgs
, ...
}:
let
  cfg = config.features.kometa;

  # The config.yml lives in this module dir so it's reviewable + diff-able
  # in git. Read into the Nix store as an immutable file and bind-mounted
  # read-only inside the container.
  configFile = pkgs.writeText "kometa-config.yml" (builtins.readFile ./config.yml);
in
{
  options.features.kometa = {
    enable = lib.mkEnableOption "Kometa (Plex Meta Manager)";
  };

  config = lib.mkIf cfg.enable {
    age.secrets."kometa-env" = {
      file = ../../../secrets/kometa-env.age;
      mode = "0400";
    };

    # Mirror skill-pool.nix: container infrastructure declared per-host
    # rather than globally; this also picks up podman as the backend.
    virtualisation.podman.enable = lib.mkDefault true;

    virtualisation.oci-containers = {
      backend = "podman";

      containers."kometa" = {
        image = "kometateam/kometa:latest";
        autoStart = true;
        environmentFiles = [ config.age.secrets."kometa-env".path ];
        volumes = [
          # /config is Kometa's writable working dir (logs, cache, assets,
          # generated report YAMLs).
          "/var/lib/kometa:/config"
          # Overlay the read-only config.yml on top — host filesystem ->
          # Nix-store-immutable, container sees /config/config.yml as ro.
          "${configFile}:/config/config.yml:ro"
        ];
        extraOptions = [
          # Host network: lets Kometa reach Plex at localhost:32400 + any
          # *arr service on its loopback port without container DNS
          # gymnastics. Acceptable isolation tradeoff: Kometa only makes
          # outbound calls (Plex API + TMDB), no inbound surface.
          "--network=host"
        ];
      };
    };

    systemd.tmpfiles.rules = [
      "d /var/lib/kometa 0755 root root - -"
      "d /var/lib/kometa/assets 0755 root root - -"
      "d /var/lib/kometa/logs 0755 root root - -"
    ];
  };
}
