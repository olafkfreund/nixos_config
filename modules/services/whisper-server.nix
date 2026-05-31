# whisper-server — local Whisper transcription HTTP API
#
# Wraps `whisper-server` from pkgs.whisper-cpp. Used by `voice-input` clients
# on razer + p620 to convert speech-to-text via a hold-to-talk hotkey.
#
# Default deployment: p620 hosts the server (it has the CPU/GPU budget),
# razer reaches it over the tailnet. p510 is irrelevant — headless.
#
# Service surface:
#   POST http://p620:9300/inference  multipart  file=@audio.wav  →  transcript
#
# Designed to be cheap to run idle: the binary memory-maps the model and
# only burns CPU when a request comes in.
{ config
, lib
, pkgs
, ...
}:
let
  cfg = config.features.whisper-server;
in
{
  options.features.whisper-server = {
    enable = lib.mkEnableOption "Whisper.cpp HTTP transcription server";

    port = lib.mkOption {
      type = lib.types.port;
      default = 9300;
      description = "TCP port for the HTTP inference endpoint.";
    };

    model = lib.mkOption {
      type = lib.types.str;
      default = "base.en";
      example = "small.en";
      description = ''
        ggml model name (passed to whisper-cpp-download-ggml-model). Sizes:
          tiny.en   ≈  40 MB, fastest, lowest accuracy
          base.en   ≈ 150 MB, good balance for short dictation
          small.en  ≈ 500 MB, more accurate, slower
          medium.en ≈ 1.5 GB
      '';
    };

    openFirewallOnTailscale = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Open the service port on the tailscale0 interface only.";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.whisper-server = {
      description = "whisper.cpp HTTP inference server";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];

      # Download the model into StateDirectory on first run; subsequent
      # starts are zero-cost.
      preStart = ''
        cd /var/lib/whisper
        if [ ! -f ggml-${cfg.model}.bin ]; then
          ${pkgs.whisper-cpp}/bin/whisper-cpp-download-ggml-model ${cfg.model} .
        fi
      '';

      serviceConfig = {
        ExecStart = ''
          ${pkgs.whisper-cpp}/bin/whisper-server \
            --model /var/lib/whisper/ggml-${cfg.model}.bin \
            --host 0.0.0.0 \
            --port ${toString cfg.port} \
            --threads 4
        '';

        # Hardening — typical NixOS-best-practices defaults.
        DynamicUser = true;
        StateDirectory = "whisper";
        StateDirectoryMode = "0750";
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        PrivateDevices = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        RestrictAddressFamilies = [ "AF_INET" "AF_INET6" "AF_UNIX" ];
        RestrictNamespaces = true;
        LockPersonality = true;
        MemoryDenyWriteExecute = false; # whisper-cpp JITs
        NoNewPrivileges = true;
        SystemCallFilter = [ "@system-service" "~@privileged" ];

        # Sized for base.en — bump if you switch to small/medium.
        MemoryMax = "1G";
        TasksMax = 64;

        Restart = "on-failure";
        RestartSec = 5;
      };
    };

    networking.firewall.interfaces.tailscale0 = lib.mkIf cfg.openFirewallOnTailscale {
      allowedTCPPorts = [ cfg.port ];
    };
  };
}
