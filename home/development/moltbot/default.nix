{ config, lib, inputs, ... }:

with lib;

let
  cfg = config.programs.moltbot;
in
{
  # Import the nix-moltbot Home Manager module
  imports = [
    inputs.nix-moltbot.homeManagerModules.moltbot
  ];

  options.programs.moltbot = {
    # Wrapper option to control whether we configure moltbot with our defaults
    configureWithDefaults = mkOption {
      type = types.bool;
      default = true;
      description = ''
        When enabled, configures moltbot with sensible defaults for this NixOS
        infrastructure including Agenix secret paths and recommended plugins.

        Set to false if you want to configure moltbot manually using the
        upstream options directly.
      '';
    };

    telegram = {
      userIds = mkOption {
        type = types.listOf types.int;
        default = [ ];
        example = [ 123456789 ];
        description = ''
          List of Telegram user IDs allowed to interact with the bot.
          Get your user ID by messaging @userinfobot on Telegram.
        '';
      };
    };

    enabledPlugins = {
      summarize = mkOption {
        type = types.bool;
        default = false;
        description = "Enable the summarize plugin for web page summaries";
      };

      peekaboo = mkOption {
        type = types.bool;
        default = false;
        description = "Enable the peekaboo plugin for image analysis";
      };

      oracle = mkOption {
        type = types.bool;
        default = false;
        description = "Enable the oracle plugin for predictions";
      };
    };
  };

  config = mkIf (cfg.enable && cfg.configureWithDefaults) {
    # Configure moltbot with our Agenix-managed secrets
    programs.moltbot = {
      # Telegram provider configuration - only if user IDs are set
      providers.telegram = mkIf (cfg.telegram.userIds != [ ]) {
        enable = true;
        # Use Agenix-managed secret for bot token
        botTokenFile = "/run/agenix/moltbot-telegram-token";
        allowFrom = cfg.telegram.userIds;
      };

      # Anthropic provider configuration (uses existing api-anthropic secret)
      providers.anthropic = {
        apiKeyFile = "/run/agenix/api-anthropic";
      };

      # Disable all first-party plugins by default to avoid build issues
      # Users can enable them individually if needed
      firstParty = {
        summarize.enable = cfg.enabledPlugins.summarize;
        peekaboo.enable = cfg.enabledPlugins.peekaboo;
        oracle.enable = cfg.enabledPlugins.oracle;
      };

      # Use instances to configure the service explicitly
      instances.default = {
        systemd = {
          enable = true;
          unitName = "moltbot-gateway";
        };
      };
    };

    # Add warning if Telegram user IDs not configured
    warnings = optional (cfg.telegram.userIds == [ ]) ''
      Moltbot is enabled but no Telegram user IDs are configured.
      The bot won't respond to anyone. Set programs.moltbot.telegram.userIds
      to a list of authorized Telegram user IDs.
    '';
  };
}
