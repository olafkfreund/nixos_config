# API Keys Management with Age Encryption
{ config
, lib
, pkgs
, ...
}:
let
  inherit (lib) mkOption mkIf mkEnableOption types;
  cfg = config.secrets.apiKeys;

  # Get the main user from host variables
  vars = import ../../hosts/${config.networking.hostName}/variables.nix { };
  inherit (vars) username;
in
{
  options.secrets.apiKeys = {
    enable = mkEnableOption "Enable encrypted API keys management";

    enableEnvironmentVariables = mkOption {
      type = types.bool;
      default = true;
      description = "Export API keys as environment variables system-wide";
    };

    enableUserEnvironment = mkOption {
      type = types.bool;
      default = true;
      description = "Export API keys in user shell environment";
    };
  };

  config = mkIf cfg.enable {
    # Define age secrets for API keys
    age.secrets = {
      # Provider API keys: 0400 and owned by the user. Every reader (ai-cli,
      # omarchy-voice, voice-input, claude-router) runs as that user, and a
      # world-readable key could be read by any local process, including a
      # prompt-injected reviewer (#1831).
      api-openai = {
        file = ../../secrets/api-openai.age;
        mode = "0400";
        owner = "olafkfreund";
        group = "users";
      };

      api-gemini = {
        file = ../../secrets/api-gemini.age;
        mode = "0400";
        owner = "olafkfreund";
        group = "users";
      };

      api-anthropic = {
        file = ../../secrets/api-anthropic.age;
        mode = "0400";
        owner = "olafkfreund";
        group = "users";
      };

      # ElevenLabs, for omarchy-voice's cloud voice.
      #
      # 0400 and owned by the user, like the provider keys above: read by a
      # systemd *user* service, and a metered TTS key that any local process
      # can read is a bill waiting to happen. Losing access costs voice
      # quality, not voice: omarchy-voice falls back to the local Piper voice
      # and logs why.
      api-elevenlabs = {
        file = ../../secrets/api-elevenlabs.age;
        mode = "0400";
        owner = "olafkfreund";
        group = "users";
      };

      api-groq = {
        file = ../../secrets/api-groq.age;
        mode = "0400";
        owner = "olafkfreund";
        group = "users";
      };

      # Ollama cloud-models API key. Read by the ollama systemd daemon (when
      # features.ollama-server.cloudApiKeyFile points here) and by interactive
      # shells via load-api-keys → OLLAMA_API_KEY.
      api-ollama = {
        file = ../../secrets/api-ollama.age;
        mode = "0644";
        owner = "root";
        group = "users";
      };

      # api-qwen = {
      #   file = ../../secrets/api-qwen.age;
      #   mode = "0644";
      #   owner = "root";
      #   group = "users";
      # };

      # api-langchain = {
      #   file = ../../secrets/api-langchain.age;
      #   mode = "0600";
      #   owner = username;
      #   group = "users";
      # };

      api-github-token = {
        file = ../../secrets/api-github-token.age;
        mode = "0600";
        owner = username;
        group = "users";
      };

      # Cachix auth token. 0600 user-owned: only interactive `cachix push`
      # uses it, no daemon needs to read it.
      cachix-auth-token = {
        file = ../../secrets/cachix-auth-token.age;
        mode = "0600";
        owner = username;
        group = "users";
      };

      # Matrix registration token for the agent bus. Declared here rather than
      # in modules/services/matrix-continuwuity.nix because two different
      # consumers need it: the homeserver daemon on p510 reads it as the
      # `continuwuity` system user, and every Claude Code session reads it as
      # the login user to register its own identity.
      #
      # 0644 for exactly that reason -- `continuwuity` is a system user and is
      # not in `users`, so 0640 root:users would lock the daemon out. It grants
      # account creation on a non-federating homeserver, nothing more.
      matrix-registration-token = {
        file = ../../secrets/matrix-registration-token.age;
        mode = "0644";
        owner = "root";
        group = "users";
      };

      # Matrix room-administration token (@agent-p510). Declared alongside the
      # registration token above and for the same reason: every Claude Code
      # session needs it, because `#agents` is invite-only and a new session
      # must invite itself before it can join (#1687).
      #
      # 0640 root:users, unlike the registration token's 0644 -- no system
      # daemon reads this one, only the login user, and it grants room
      # administration rather than mere account creation.
      agent-bus-matrix-token = {
        file = ../../secrets/agent-bus-matrix-token.age;
        mode = "0640";
        owner = "root";
        group = "users";
      };

      synechron-github-api = {
        file = ../../secrets/synechron-github-api.age;
        mode = "0600";
        owner = username;
        group = "users";
      };

      # AWS long-lived IAM key for synechron-terraform-cli (migration/Terraform
      # provisioning). Decrypts to /run/agenix/aws-synechron-terraform on every
      # host; the file is an AWS credentials-file block under [synechron-tf],
      # consumed via AWS_SHARED_CREDENTIALS_FILE. Rotate/delete after migration.
      aws-synechron-terraform = {
        file = ../../secrets/aws-synechron-terraform.age;
        mode = "0600";
        owner = username;
        group = "users";
      };

      tailscale-auth-key = {
        file = ../../secrets/tailscale-auth-key.age;
        mode = "0600";
        owner = "root";
        group = "root";
      };
    }
    # gogcli refresh-token export — wired only once the encrypted file exists
    # (the user runs `gog login` + `gog auth tokens export` first), so builds
    # pass before the one-time OAuth. Owned by the user so the gog-token-import
    # user service can read it.
    // lib.optionalAttrs (builtins.pathExists ../../secrets/gogcli-token.age) {
      gogcli-token = {
        file = ../../secrets/gogcli-token.age;
        mode = "0600";
        owner = username;
        group = "users";
      };
    }
    # Password for gog's file keyring backend — read by gog-token-import (to
    # seed the keyring) and the gogmail launcher (to read it at runtime).
    // lib.optionalAttrs (builtins.pathExists ../../secrets/gogcli-keyring-password.age) {
      gogcli-keyring-password = {
        file = ../../secrets/gogcli-keyring-password.age;
        mode = "0600";
        owner = username;
        group = "users";
      };
    }
    # gog OAuth client credentials JSON — dropped into GOG_HOME by the
    # gog-token-import service so gog can mint access tokens.
    // lib.optionalAttrs (builtins.pathExists ../../secrets/gogcli-credentials.json.age) {
      gogcli-credentials-json = {
        file = ../../secrets/gogcli-credentials.json.age;
        mode = "0600";
        owner = username;
        group = "users";
      };
    };

    # Note: System environment variables removed - use shell initialization instead
    # The load-api-keys script properly handles dynamic loading of API keys

    # Create utility scripts for API key management
    environment.systemPackages = [
      (pkgs.writeScriptBin "load-api-keys" ''
        #!/bin/sh
        # Load API keys from encrypted storage

        # Try to load API keys from agenix secrets. The OpenAI, Anthropic,
        # Gemini and Groq keys are deliberately not exported: agents use their
        # subscription logins, and a tool that needs a key reads it for that
        # one command from /run/agenix (#1831).
        if [ -r "/run/agenix/api-ollama" ]; then
          # Ollama cloud-models token (Ollama Turbo / hosted models). The local
          # ollama daemon picks this up from its own EnvironmentFile, but
          # exporting here lets `ollama` CLI invocations and curl against
          # api.ollama.com authenticate from the shell too.
          echo "export OLLAMA_API_KEY=\"$(cat /run/agenix/api-ollama)\""
        fi

        if [ -r "/run/agenix/api-github-token" ]; then
          # Export as GITHUB_API_TOKEN to avoid conflict with gh CLI credential management
          # gh CLI expects to manage its own credentials via 'gh auth login'
          echo "export GITHUB_API_TOKEN=\"$(cat /run/agenix/api-github-token)\""
        fi

        if [ -r "/run/agenix/cachix-auth-token" ]; then
          echo "export CACHIX_AUTH_TOKEN=\"$(cat /run/agenix/cachix-auth-token)\""
        fi

        if [ -r "/run/agenix/synechron-github-api" ]; then
          echo "export SYNECHRON_GITHUB_API_TOKEN=\"$(cat /run/agenix/synechron-github-api)\""
        fi

        # If no secrets are available, output nothing (safe for eval)
        true
      '')

      (pkgs.writeScriptBin "api-keys-status" ''
        #!/bin/bash
        echo "API Keys Status:"
        echo "==============="

        # Check environment variables
        [ -n "$OLLAMA_API_KEY" ] && echo "✅ Ollama Cloud: Available" || echo "❌ Ollama Cloud: Not available"
        [ -n "$LANGCHAIN_API_KEY" ] && echo "✅ LangChain: Available" || echo "❌ LangChain: Not available"
        [ -n "$GITHUB_API_TOKEN" ] && echo "✅ GitHub API Token: Available" || echo "❌ GitHub API Token: Not available"

        echo ""
        echo "Secret Files:"
        echo "============="

        # Check secret files by name: /run/agenix.d is traversable but not
        # listable for users (drwxr-x--x), so a find over it printed nothing.
        for name in api-openai api-anthropic api-gemini api-groq api-ollama api-github-token; do
          file="/run/agenix/$name"
          if [ -r "$file" ] && [ -s "$file" ]; then
            echo "✅ $name: $file"
          fi
        done
      '')
    ];

    # Add to user shell initialization (for interactive sessions)
    programs.zsh.interactiveShellInit = mkIf cfg.enableUserEnvironment ''
      # Load API keys if available
      if command -v load-api-keys >/dev/null 2>&1; then
        eval "$(load-api-keys 2>/dev/null)"
      fi
    '';

    programs.bash.interactiveShellInit = mkIf cfg.enableUserEnvironment ''
      # Load API keys if available
      if command -v load-api-keys >/dev/null 2>&1; then
        eval "$(load-api-keys 2>/dev/null)"
      fi
    '';

    # TEMPORARY: Completely disabled activation script until secrets are recreated
    # system.activationScripts.api-keys-setup = {
    #   text = ''
    #     echo "API keys setup - temporarily disabled for broken secrets"
    #   '';
    #   deps = [ "agenix" ];
    # };
  };
}
