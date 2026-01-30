# Openclaw AI Assistant Gateway (formerly Moltbot)
# Homepage: https://github.com/moltbot/nix-moltbot (now nix-openclaw)
{ config, lib, inputs, ... }:

with lib;

let
  cfg = config.programs.openclaw;
in
{
  # Import the nix-openclaw Home Manager module
  imports = [
    inputs.nix-moltbot.homeManagerModules.openclaw
  ];

  options.programs.openclaw = {
    # Wrapper option to control whether we configure openclaw with our defaults
    configureWithDefaults = mkOption {
      type = types.bool;
      default = true;
      description = ''
        When enabled, configures Openclaw with sensible defaults for this NixOS
        infrastructure including Agenix secret paths and recommended plugins.

        Set to false if you want to configure Openclaw manually using the
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
        description = "Enable the peekaboo plugin for image analysis (screenshots)";
      };

      oracle = mkOption {
        type = types.bool;
        default = false;
        description = "Enable the oracle plugin for web search predictions";
      };
    };
  };

  config = mkIf (cfg.enable && cfg.configureWithDefaults) {
    # Configure Openclaw with our Agenix-managed secrets
    programs.openclaw = {
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
          unitName = "openclaw-gateway";
        };
      };
    };

    # Add warning if Telegram user IDs not configured
    warnings = optional (cfg.telegram.userIds == [ ]) ''
      Openclaw is enabled but no Telegram user IDs are configured.
      The bot won't respond to anyone. Set programs.openclaw.telegram.userIds
      to a list of authorized Telegram user IDs.
    '';
  };
}
