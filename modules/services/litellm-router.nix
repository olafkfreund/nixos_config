# LiteLLM proxy — Anthropic-compat router that fronts the local Ollama
# service. Lets Claude Code (which speaks the Anthropic API natively) reach
# local Ollama models by setting ANTHROPIC_BASE_URL per repo.
#
# Architecture:
#   Claude Code  →  http(s)://p620.../router (LiteLLM)  →  127.0.0.1:11434 (Ollama)
#
# Model aliases:
#   claude-sonnet-4-6  →  qwen3:14b          (default coding model — primary)
#   claude-opus-4-6    →  gemma4:e4b         (light/fast on-demand)
#   qwen3              →  qwen3:14b          (native name passthrough)
#   qwen3.6            →  qwen3:14b          (backward compatibility alias)
#   qwen2.5-coder      →  qwen2.5-coder:14b  (previous default, still pulled)
#   gemma4             →  gemma4:e4b         (backward compatibility alias)
#
# Authentication: a single master bearer key loaded at runtime from agenix
# (/run/agenix/litellm-master-key). Per-host clients hold the same plaintext
# under their own .age files (api-router-p620, api-router-razer — Phase 3).
#
# Network: binds 0.0.0.0:4000 but firewall opens it only on tailscale0 and
# the configured LAN interface — never globally reachable.
#
# See docs/plans/2026-05-22-ollama-p620-litellm-design.md §5 for full design.
{ config
, lib
, pkgs
, ...
}:
let
  cfg = config.features.litellm-router;

  configFile = pkgs.writeText "litellm-config.yaml" ''
    model_list:
      # Anthropic-compatible aliases that Claude Code recognises by name.
      - model_name: claude-sonnet-4-6
        litellm_params:
          model: ollama_chat/qwen3:14b
          api_base: http://127.0.0.1:11434
          additional_drop_params: ["thinking", "think", "reasoning_effort"]

      - model_name: claude-opus-4-6
        litellm_params:
          model: ollama_chat/gemma4:e4b
          api_base: http://127.0.0.1:11434
          additional_drop_params: ["thinking", "think", "reasoning_effort"]

      # Native names for ai-cli / aichat / direct OpenAI-compat clients.
      - model_name: qwen3
        litellm_params:
          model: ollama_chat/qwen3:14b
          api_base: http://127.0.0.1:11434
          additional_drop_params: ["thinking", "think", "reasoning_effort"]

      - model_name: qwen3.6
        litellm_params:
          model: ollama_chat/qwen3:14b
          api_base: http://127.0.0.1:11434
          additional_drop_params: ["thinking", "think", "reasoning_effort"]

      - model_name: qwen2.5-coder
        litellm_params:
          model: ollama_chat/qwen2.5-coder:14b
          api_base: http://127.0.0.1:11434
          additional_drop_params: ["thinking", "think", "reasoning_effort"]

      - model_name: gemma4
        litellm_params:
          model: ollama_chat/gemma4:e4b
          api_base: http://127.0.0.1:11434
          additional_drop_params: ["thinking", "think", "reasoning_effort"]

      # Explicit model:tag passthroughs (for clients that send the raw Ollama name).
      - model_name: qwen3:14b
        litellm_params:
          model: ollama_chat/qwen3:14b
          api_base: http://127.0.0.1:11434
          additional_drop_params: ["thinking", "think", "reasoning_effort"]

      - model_name: qwen2.5-coder:14b
        litellm_params:
          model: ollama_chat/qwen2.5-coder:14b
          api_base: http://127.0.0.1:11434
          additional_drop_params: ["thinking", "think", "reasoning_effort"]

      - model_name: gemma4:e4b
        litellm_params:
          model: ollama_chat/gemma4:e4b
          api_base: http://127.0.0.1:11434
          additional_drop_params: ["thinking", "think", "reasoning_effort"]

    general_settings:
      master_key: os.environ/LITELLM_MASTER_KEY

    litellm_settings:
      drop_params: true      # silently drop Anthropic-only params (cache_control etc.)
      set_verbose: true
  '';
in
{
  options.features.litellm-router = {
    enable = lib.mkEnableOption "LiteLLM proxy fronting the local Ollama service";

    port = lib.mkOption {
      type = lib.types.port;
      default = 4000;
      description = "Port LiteLLM binds to (loopback always; tailnet + LAN via firewall).";
    };

    listenLanInterface = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "enp1s0";
      description = ''
        LAN interface to open the port on (in addition to tailscale0 and
        loopback). Set to the host's actual LAN NIC; confirm with `ip link`.
        Set to null to expose only via Tailscale.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    age.secrets."litellm-master-key" = {
      file = ../../secrets/litellm-master-key.age;
      mode = "0400";
    };

    systemd.services.litellm-router = {
      description = "LiteLLM Proxy — Anthropic-compat router → Ollama";
      after = [ "network-online.target" "ollama.service" ];
      wants = [ "network-online.target" "ollama.service" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        ExecStart = pkgs.writeShellScript "litellm-router-start" ''
          export LITELLM_MASTER_KEY="$(cat "$CREDENTIALS_DIRECTORY/litellm-master-key")"
          exec ${pkgs.litellm}/bin/litellm \
            --config ${configFile} \
            --port ${toString cfg.port} \
            --host 0.0.0.0
        '';

        DynamicUser = true;
        LoadCredential = [ "litellm-master-key:${config.age.secrets."litellm-master-key".path}" ];

        # Hardening (matches docs/PATTERNS.md security baseline)
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        PrivateDevices = true;
        ProtectKernelTunables = true;
        ProtectControlGroups = true;
        ProtectKernelModules = true;
        ProtectKernelLogs = true;
        ProtectClock = true;
        ProtectHostname = true;
        NoNewPrivileges = true;
        RestrictSUIDSGID = true;
        RestrictRealtime = true;
        RestrictNamespaces = true;
        LockPersonality = true;
        MemoryDenyWriteExecute = false; # python JITs (some deps) need this
        SystemCallFilter = [ "@system-service" "~@privileged" ];

        # Resource limits
        MemoryMax = "2G";
        TasksMax = 256;

        # Reliability
        Restart = "on-failure";
        RestartSec = 5;
      };
    };

    # Firewall: open :4000 ONLY on tailscale0 + optional LAN iface.
    # Never added to the global `allowedTCPPorts` — loopback always works.
    networking.firewall.interfaces = lib.mkMerge [
      {
        "tailscale0".allowedTCPPorts = [ cfg.port ];
      }
      (lib.mkIf (cfg.listenLanInterface != null) {
        "${cfg.listenLanInterface}".allowedTCPPorts = [ cfg.port ];
      })
    ];
  };
}
