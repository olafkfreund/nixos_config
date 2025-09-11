# Server Template - Headless Server Configuration
# Used by: DEX5550 (monitoring server), P510 (media server)
{ config, lib, pkgs, ... }:
{
  imports = [
    ../../modules/core.nix
    ../../modules/monitoring.nix
    ../../modules/performance.nix
    ../../modules/cloud.nix
    ../../modules/development.nix # Minimal dev tools for administration
    ../../modules/email.nix
    ../../modules/programs-server.nix # Server-specific programs without desktop apps
    ../../modules/virtualization.nix # Needed for containers (Docker/Podman)
    ../../modules/common/ai-defaults.nix
    # No desktop modules for servers
  ];

  # Server-specific defaults
  config = {
    aiDefaults = {
      enable = lib.mkDefault true;
      profile = "server"; # Disables Ollama to save resources
    };

    # Server-specific optimizations
    services = {
      openssh = {
        enable = lib.mkDefault true;
        settings.PermitRootLogin = lib.mkDefault "no";
      };
    };

    # Disable GUI components
    services.xserver.enable = lib.mkDefault false;
    programs.hyprland.enable = lib.mkDefault false;
  };
}
