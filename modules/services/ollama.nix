# Ollama coding-model server (services.ollama wrapper).
#
# Designed for p620's RX 7900 XTX (gfx1100, 24GB VRAM, ROCm). The single
# GPU comfortably fits each default model individually (qwen3.8:27b ~18GB,
# gemma4:26b MoE ~18GB) but NOT both at once (~36GB > 24GB), so
# MAX_LOADED_MODELS=1 forces deterministic evict-then-load on switch.
#
# Default model choices (Aug 2026):
#   Persistent: qwen3.8:27b — 18GB Q4, 256K context. DENSE 27B, so unlike a
#     MoE nothing here is free: everything that spills out of VRAM is paid
#     for at full width. It stays affordable because the architecture is
#     hybrid — only 16 of its 64 layers run full attention, the other 48 use
#     linear attention with a constant recurrent state, so the KV cache
#     barely grows with context. That is what makes a large `contextLength`
#     practical on a 24GB card.
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
      default = [ "qwen3.8:27b" ];
      description = ''
        Models pulled at activation and used as the default coding model.
        Listed first in the load priority. Default qwen3.8:27b (~18GB,
        256K context, strong agentic tool calling).

        Leave empty on hosts whose GPUs are shared with something else — a
        persistent model holds its VRAM until `keepAlive` expires.
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

    contextLength = lib.mkOption {
      type = lib.types.nullOr lib.types.int;
      default = null;
      example = 32768;
      description = ''
        Value for OLLAMA_CONTEXT_LENGTH — the context window the server uses
        for requests that do not set `num_ctx` themselves.

        Ollama defaults to 4096 no matter what the model supports, so a
        256K-context model like qwen3.8:27b is capped at 4096 unless this is
        raised. Cost is VRAM for the KV cache on top of the weights, so the
        ceiling is the card, not the model — raise it only as far as the
        headroom above the resident model allows.
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
      }
      // lib.optionalAttrs (cfg.contextLength != null) {
        OLLAMA_CONTEXT_LENGTH = toString cfg.contextLength;
      };
    };

    # nixpkgs' loadModels generates ollama-model-loader.service, which pulls
    # models over the network (After=ollama.service network-online.target,
    # Restart=on-failure). During a `switch`, systemd-resolved + NetworkManager
    # restart mid-activation, so DNS is briefly down and the pulls fail
    # ("lookup registry.ollama.ai: no such host"). The unit's own Restart=
    # recovers seconds later, but `nixos-rebuild switch` samples the unit while
    # it's momentarily failed and aborts the whole deploy (exit 4 → rollback).
    # Don't re-run it on switch — it loads models at next boot when DNS is up.
    systemd.services.ollama-model-loader.restartIfChanged = false;

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
