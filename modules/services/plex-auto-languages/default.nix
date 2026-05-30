# Plex-Auto-Languages (PAL) — per-show audio + subtitle track preference
# memorization for Plex.
#
# Watches Plex for play events and scan events (via the Plex websocket
# API, no Plex Pass needed for that path — only the optional webhook
# integration requires Pass). When a user plays an episode, PAL records
# the audio/subtitle track choice; future episodes of the same series
# automatically get those tracks selected on play.
#
# Phase 1: tracking mode, all libraries with shows, no filter labels.
#
# Pattern mirrors modules/services/kometa/default.nix exactly (oci-
# containers + envsubst-rendered config + agenix env file). The lessons
# from the Kometa journey are baked in: no fictional systemd deps, real
# env-var substitution via envsubst-not-Kometa-magic, repo template as
# source of truth + rendered file under /var/lib for container mount.
{ config
, lib
, pkgs
, ...
}:
let
  cfg = config.features.plex-auto-languages;
  configTemplate = ./config.yaml;
in
{
  options.features.plex-auto-languages = {
    enable = lib.mkEnableOption "Plex-Auto-Languages";
  };

  config = lib.mkIf cfg.enable {
    age.secrets."plex-auto-languages-env" = {
      file = ../../../secrets/plex-auto-languages-env.age;
      mode = "0400";
    };

    virtualisation.podman.enable = lib.mkDefault true;

    virtualisation.oci-containers = {
      backend = "podman";

      containers."plex-auto-languages" = {
        image = "remirigal/plex-auto-languages:latest";
        autoStart = true;
        environmentFiles = [ config.age.secrets."plex-auto-languages-env".path ];
        volumes = [
          # /config is PAL's working dir (config.yaml + db.sqlite for
          # tracking state).
          "/var/lib/plex-auto-languages:/config"
        ];
        extraOptions = [
          # Host network: reach localhost:32400 (Plex) directly. PAL has
          # no inbound surface — Plex notifies it via its own websocket
          # API, not webhooks-into-PAL — so no port mapping needed.
          "--network=host"
        ];
      };
    };

    systemd.tmpfiles.rules = [
      "d /var/lib/plex-auto-languages 0755 root root - -"
    ];

    # Render the config template into /var/lib/plex-auto-languages/config.yaml
    # on every activation, substituting ${PLEX_URL} and ${PLEX_TOKEN} from
    # the agenix-decrypted env file. Runs before podman-plex-auto-languages
    # so the container always finds a fresh, secret-populated config.
    systemd.services.plex-auto-languages-config-render = {
      description = "Render PAL config.yaml from template + agenix secrets";
      wantedBy = [ "podman-plex-auto-languages.service" ];
      before = [ "podman-plex-auto-languages.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = false;
        EnvironmentFile = config.age.secrets."plex-auto-languages-env".path;
        ExecStart = pkgs.writeShellScript "plex-auto-languages-render-config" ''
          set -euo pipefail
          ${pkgs.gettext}/bin/envsubst < ${configTemplate} > /var/lib/plex-auto-languages/config.yaml.new
          mv -f /var/lib/plex-auto-languages/config.yaml.new /var/lib/plex-auto-languages/config.yaml
          chmod 0640 /var/lib/plex-auto-languages/config.yaml
        '';
      };
    };

    systemd.services.podman-plex-auto-languages = {
      after = [ "plex-auto-languages-config-render.service" ];
      requires = [ "plex-auto-languages-config-render.service" ];
    };
  };
}
