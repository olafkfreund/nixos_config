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
# Bind address is configurable via `host` (default 127.0.0.1). Set to
# "0.0.0.0" to expose on all interfaces — note Ollama has no built-in
# auth, so restrict access via firewall / tailnet ACLs when bound wider.
# OLLAMA_ORIGINS="*" is set so browser UIs from any origin can call the
# API; this only matters once the bind is non-loopback.
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

    host = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      example = "0.0.0.0";
      description = ''
        Bind address for Ollama's HTTP API. Default 127.0.0.1 (loopback
        only). Set to "0.0.0.0" to expose on all interfaces — Ollama has
        no auth, so combine with firewall / tailnet ACLs when widening.
      '';
    };

    origins = lib.mkOption {
      type = lib.types.str;
      default = "*";
      description = ''
        Value for OLLAMA_ORIGINS — comma-separated list of allowed
        browser origins for CORS. Defaults to "*" so any local or remote
        web UI can call the API. Tighten if you want browser-origin
        restriction (network exposure is controlled by `host`, not this).
      '';
    };

    cloudApiKeyFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      example = lib.literalExpression ''config.age.secrets."api-ollama".path'';
      description = ''
        Runtime path to a file containing the raw Ollama cloud-models API key
        (no `OLLAMA_API_KEY=` prefix — just the token). When set, the daemon
        starts with OLLAMA_API_KEY in its environment, enabling access to
        Ollama's hosted cloud models. The key is composed into an
        EnvironmentFile under /run/ollama at preStart, so it never lands in
        the Nix store. When null, the daemon runs local-only.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    services.ollama = {
      enable = true;
      inherit (cfg) package;
      inherit (cfg) host;
      port = 11434;
      loadModels = cfg.persistentModels ++ cfg.onDemandModels;
      modelsDir = lib.mkIf (cfg.modelsDir != null) cfg.modelsDir;
      environmentVariables = {
        # Required for RX 7900 XTX (gfx1100) ROCm — also set globally in
        # hosts/p620/nixos/amd.nix, restated here for unit-local clarity.
        HSA_OVERRIDE_GFX_VERSION = "11.0.0";
        ROCR_VISIBLE_DEVICES = cfg.rocrVisibleDevices;

        OLLAMA_KEEP_ALIVE = cfg.keepAlive;
        OLLAMA_NUM_PARALLEL = "1";
        OLLAMA_MAX_LOADED_MODELS = "1";
        OLLAMA_FLASH_ATTENTION = "1";
        OLLAMA_ORIGINS = cfg.origins;
      };
    };

    # Lower priority + higher OOM score: the user's interactive desktop
    # wins tiebreaks under contention.
    systemd.services.ollama.serviceConfig = {
      OOMScoreAdjust = 200;
      Nice = 10;
      IOSchedulingClass = "best-effort";
      IOSchedulingPriority = 5;
    } // lib.optionalAttrs (cfg.cloudApiKeyFile != null) {
      # systemd creates /run/ollama as ollama:ollama mode 0750 *before*
      # ExecStartPre fires, so preStart doesn't need to mkdir or chown.
      RuntimeDirectory = "ollama";
      RuntimeDirectoryMode = "0750";

      # Composed by preStart below; never enters the Nix store. The leading
      # `-` marks it optional: systemd applies EnvironmentFile= to every
      # Exec*= in the unit including ExecStartPre=, so on first start (before
      # preStart has created the file) the load must not fail. preStart runs
      # without the env var (doesn't need it), creates the file, then
      # ExecStart re-reads EnvironmentFile= and picks up OLLAMA_API_KEY.
      EnvironmentFile = "-/run/ollama/cloud-env";
    };

    # Compose the OLLAMA_API_KEY env file at service start from the agenix
    # path. /run/ollama already exists (RuntimeDirectory above). umask 027
    # makes the file 0640 owned by the unit's User=/Group= (ollama:ollama).
    systemd.services.ollama.preStart = lib.mkIf (cfg.cloudApiKeyFile != null) (lib.mkAfter ''
      umask 027
      printf 'OLLAMA_API_KEY=%s\n' "$(tr -d '\r\n' < ${cfg.cloudApiKeyFile})" > /run/ollama/cloud-env
    '');
  };
}
