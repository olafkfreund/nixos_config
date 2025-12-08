{ config
, lib
, ...
}:
with lib; let
  cfg = config.features;
in
{
  imports = [
    ./features.nix
  ];

  # Optimized config - reduced mkMerge complexity for better performance
  config = {
    # Development tools (conditional enables)
    ansible.development.enable = mkIf cfg.development.enable cfg.development.ansible;
    cargo.development.enable = mkIf cfg.development.enable cfg.development.cargo;
    development.copilot-cli.enable = mkIf cfg.development.enable cfg.development.copilot-cli;
    github.development.enable = mkIf cfg.development.enable cfg.development.github;
    go.development.enable = mkIf cfg.development.enable cfg.development.go;
    java.development.enable = mkIf cfg.development.enable cfg.development.java;
    lua.development.enable = mkIf cfg.development.enable cfg.development.lua;
    nix.development.enable = mkIf cfg.development.enable cfg.development.nix;
    shell.development.enable = mkIf cfg.development.enable cfg.development.shell;
    devshell.development.enable = mkIf cfg.development.enable cfg.development.devshell;
    nodejs.development.enable = mkIf cfg.development.enable cfg.development.nodejs;

    # Modules configuration
    modules = {
      development.python.enable = mkIf cfg.development.enable cfg.development.python;
      containers.docker.enable = mkIf cfg.virtualization.enable cfg.virtualization.docker;
      ai.gemini-cli.enable = mkIf cfg.ai.enable cfg.ai.gemini-cli;
      ai.chatgpt.enable = mkIf cfg.ai.enable (cfg.ai.chatgpt or false);
    };

    # Services configuration
    services = {
      incus.enable = mkIf cfg.virtualization.enable cfg.virtualization.incus;
      podman.enable = mkIf cfg.virtualization.enable cfg.virtualization.podman;
      spice.enable = mkIf cfg.virtualization.enable cfg.virtualization.spice;
      libvirt.enable = mkIf cfg.virtualization.enable cfg.virtualization.libvirt;
      print.enable = cfg.programs.print;
    };

    # Cloud tools (conditional enables)
    aws.packages.enable = mkIf cfg.cloud.enable cfg.cloud.aws;
    azure.packages.enable = mkIf cfg.cloud.enable cfg.cloud.azure;
    google.packages.enable = mkIf cfg.cloud.enable cfg.cloud.google;
    k8s.packages.enable = mkIf cfg.cloud.enable cfg.cloud.k8s;
    terraform.packages.enable = mkIf cfg.cloud.enable cfg.cloud.terraform;

    # Security tools (conditional enables)
    security.onepassword.enable = mkIf cfg.security.enable cfg.security.onepassword;
    security.gnupg.enable = mkIf cfg.security.enable cfg.security.gnupg;

    # Networking (conditional enables)

    # AI tools (conditional enables)
    ai.ollama.enable = mkIf cfg.ai.enable cfg.ai.ollama;

    # Enhanced AI provider support
    ai.providers = mkIf cfg.ai.providers.enable {
      enable = true;
      inherit (cfg.ai.providers) defaultProvider;
      inherit (cfg.ai.providers) enableFallback;
      inherit (cfg.ai.providers) costOptimization;

      openai = {
        inherit (cfg.ai.providers.openai) enable;
        inherit (cfg.ai.providers.openai) priority;
      };

      anthropic = {
        inherit (cfg.ai.providers.anthropic) enable;
        inherit (cfg.ai.providers.anthropic) priority;
      };

      gemini = {
        inherit (cfg.ai.providers.gemini) enable;
        inherit (cfg.ai.providers.gemini) priority;
      };

      ollama = {
        inherit (cfg.ai.providers.ollama) enable;
        inherit (cfg.ai.providers.ollama) priority;
      };
    };

    # Programs (conditional enables)
    programs = {
      lazygit.enable = cfg.programs.lazygit;
      thunderbird.enable = cfg.programs.thunderbird;
      obsidian.enable = cfg.programs.obsidian;
      office.enable = cfg.programs.office;
      webcam.enable = cfg.programs.webcam;
    };

    # Media tools (conditional enables)
    media.droidcam.enable = cfg.media.droidcam;
  };
}
