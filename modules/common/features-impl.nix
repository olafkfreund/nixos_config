{
  config,
  lib,
  ...
}:
with lib; let
  cfg = config.features;
in {
  imports = [
    ./features.nix
  ];

  # Optimized config - reduced mkMerge complexity for better performance
  config = {
    # Development tools (conditional enables)
    ansible.development.enable = mkIf cfg.development.enable cfg.development.ansible;
    cargo.development.enable = mkIf cfg.development.enable cfg.development.cargo;
    github.development.enable = mkIf cfg.development.enable cfg.development.github;
    go.development.enable = mkIf cfg.development.enable cfg.development.go;
    java.development.enable = mkIf cfg.development.enable cfg.development.java;
    lua.development.enable = mkIf cfg.development.enable cfg.development.lua;
    nix.development.enable = mkIf cfg.development.enable cfg.development.nix;
    shell.development.enable = mkIf cfg.development.enable cfg.development.shell;
    devshell.development.enable = mkIf cfg.development.enable cfg.development.devshell;
    modules.development.python.enable = mkIf cfg.development.enable cfg.development.python;
    nodejs.development.enable = mkIf cfg.development.enable cfg.development.nodejs;

    # Virtualization tools (conditional enables)
    modules.containers.docker.enable = mkIf cfg.virtualization.enable cfg.virtualization.docker;
    services.incus.enable = mkIf cfg.virtualization.enable cfg.virtualization.incus;
    services.podman.enable = mkIf cfg.virtualization.enable cfg.virtualization.podman;
    services.spice.enable = mkIf cfg.virtualization.enable cfg.virtualization.spice;
    services.libvirt.enable = mkIf cfg.virtualization.enable cfg.virtualization.libvirt;
    services.sunshine.enable = mkIf cfg.virtualization.enable cfg.virtualization.sunshine;

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
    vpn.tailscale.enable = mkIf cfg.networking.enable cfg.networking.tailscale;

    # AI tools (conditional enables)
    ai.ollama.enable = mkIf cfg.ai.enable cfg.ai.ollama;
    modules.ai.gemini-cli.enable = mkIf cfg.ai.enable cfg.ai.gemini-cli;
    modules.ai.chatgpt.enable = mkIf cfg.ai.enable (cfg.ai.chatgpt or true);

    # Programs (conditional enables)
    programs.lazygit.enable = cfg.programs.lazygit;
    programs.thunderbird.enable = cfg.programs.thunderbird;
    programs.obsidian.enable = cfg.programs.obsidian;
    programs.office.enable = cfg.programs.office;
    programs.webcam.enable = cfg.programs.webcam;
    services.print.enable = cfg.programs.print;

    # Media tools (conditional enables)
    media.droidcam.enable = cfg.media.droidcam;
  };
}
