# AI Provider Default Configuration Module
# Provides sensible defaults for AI provider configuration to eliminate duplication
{ config, lib, ... }:
let inherit (lib) mkOption mkIf mkEnableOption mkDefault types; in {
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
    };
  };
}
