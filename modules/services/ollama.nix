# Ollama coding-model server (services.ollama wrapper).
#
# Designed for p620's RX 7900 XTX (gfx1100, 24GB VRAM, ROCm). The single
# GPU comfortably fits each default model individually (qwen3.6:27b ~17GB,
# gemma4:26b MoE ~18GB) but NOT both at once (~35GB > 24GB), so
# MAX_LOADED_MODELS=1 forces deterministic evict-then-load on switch.
#
# Default model choices (May 2026):
#   Persistent: qwen3.6:27b — strong agentic tool calling (Qwen RL-trained
#     on 1M agentic envs), good for Claude Code's tool-use loops.
#   On-demand:  gemma4:26b — MoE with ~3.8B active params, very fast
#     (~80-100 tok/s) for raw code-gen bursts.
#
# Always loopback-only — never exposes :11434 to any network interface.
# Reachable only via a same-host LiteLLM proxy (or local `ollama` CLI).
#
# See docs/plans/2026-05-22-ollama-p620-litellm-design.md for the full
# design and the dual-tier model + GPU-contention rationale.
{ config
, lib
, pkgs
, ...
}:
let
  cfg = config.features.ollama-server;
in
{
  options.features.ollama-server = {
    enable = lib.mkEnableOption "Ollama coding-model server (loopback only)";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.ollama-rocm;
      defaultText = lib.literalExpression "pkgs.ollama-rocm";
      description = ''
        Ollama package. Defaults to `pkgs.ollama-rocm` for AMD GPUs (RDNA3
        / gfx1100 on p620). Switch to `pkgs.ollama-cuda` for NVIDIA hosts.
      '';
    };

    persistentModels = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "qwen3.6:27b" ];
      description = ''
        Models pulled at activation and used as the default coding model.
        Listed first in the load priority. Default qwen3.6:27b (~17GB,
        strong agentic tool calling).
      '';
    };

    onDemandModels = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "gemma4:26b" ];
      description = ''
        Alternate models pulled at activation but only loaded into VRAM on
        request. Auto-evicted after `keepAlive` of idle. Default gemma4:26b
        (~18GB MoE, ~3.8B active params, very fast raw code-gen).
      '';
    };

    modelsDir = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "/mnt/data/ollama/models";
      description = ''
        Override for where Ollama stores model blobs. Set this to a path
        on a large filesystem (~100GB+ recommended) — each Q4 model is
        ~17-20GB and multiple are typically pulled. When null, NixOS uses
        the default under /var/lib/ollama.
      '';
    };

    keepAlive = lib.mkOption {
      type = lib.types.str;
      default = "5m";
      description = ''
        Auto-unload models after this idle time. On a workstation host,
        keep this low so the GPU is released for desktop work (Blender,
        games, video editing) when not actively coding. Use "-1" for
        always-loaded if Ollama is the only GPU consumer.
      '';
    };

    rocrVisibleDevices = lib.mkOption {
      type = lib.types.str;
      default = "0";
      description = ''
        Comma-separated indices of ROCm-visible devices. Defaults to the
        first discrete GPU only; prevents accidental fallthrough to an
        integrated GPU on hybrid-graphics systems.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    services.ollama = {
      enable = true;
      inherit (cfg) package;
      host = "127.0.0.1";
      port = 11434;
      loadModels = cfg.persistentModels ++ cfg.onDemandModels;
      models = lib.mkIf (cfg.modelsDir != null) cfg.modelsDir;
      environmentVariables = {
        # Required for RX 7900 XTX (gfx1100) ROCm — also set globally in
        # hosts/p620/nixos/amd.nix, restated here for unit-local clarity.
        HSA_OVERRIDE_GFX_VERSION = "11.0.0";
        ROCR_VISIBLE_DEVICES = cfg.rocrVisibleDevices;

        OLLAMA_KEEP_ALIVE = cfg.keepAlive;
        OLLAMA_NUM_PARALLEL = "1";
        OLLAMA_MAX_LOADED_MODELS = "1";
        OLLAMA_FLASH_ATTENTION = "1";
      };
    };

    # Lower priority + higher OOM score: the user's interactive desktop
    # wins tiebreaks under contention.
    systemd.services.ollama.serviceConfig = {
      OOMScoreAdjust = 200;
      Nice = 10;
      IOSchedulingClass = "best-effort";
      IOSchedulingPriority = 5;
    };
  };
}
