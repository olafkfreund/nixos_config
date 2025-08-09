# AI Provider Default Configuration Module
# Provides sensible defaults for AI provider configuration to eliminate duplication
{ config, lib, ... }:
with lib; {
  options.aiDefaults = {
    enable = mkEnableOption "Default AI provider configuration";

    profile = mkOption {
      type = types.enum [ "workstation" "server" "laptop" ];
      default = "workstation";
      description = "AI provider profile for different host types";
    };
  };

  config = mkIf config.aiDefaults.enable {
    ai.providers = {
      enable = mkDefault true;
      defaultProvider = mkDefault "anthropic";
      enableFallback = mkDefault true;

      # Cloud providers - enabled by default on all systems
      openai.enable = mkDefault true;
      anthropic.enable = mkDefault true;
      gemini.enable = mkDefault true;

      # Local inference - profile-dependent defaults
      ollama.enable = mkDefault (
        if config.aiDefaults.profile == "server" || config.aiDefaults.profile == "laptop"
        then false  # Disable on resource-constrained systems
        else true   # Enable on workstations
      );
    };

    # Automatically enable core tools needed for AI workflows
    features.packages.coreTools = mkDefault true;
  };
}
