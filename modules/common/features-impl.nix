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

  config = mkMerge [
    # Development tools
    (mkIf cfg.development.enable {
      ansible.development.enable = cfg.development.ansible;
      cargo.development.enable = cfg.development.cargo;
      github.development.enable = cfg.development.github;
      go.development.enable = cfg.development.go;
      java.development.enable = cfg.development.java;
      lua.development.enable = cfg.development.lua;
      nix.development.enable = cfg.development.nix;
      shell.development.enable = cfg.development.shell;
      devshell.development.enable = cfg.development.devshell;
      python.development.enable = cfg.development.python;
      nodejs.development.enable = cfg.development.nodejs;
    })

    # Virtualization tools
    (mkIf cfg.virtualization.enable {
      services.docker.enable = cfg.virtualization.docker;
      services.incus.enable = cfg.virtualization.incus;
      services.podman.enable = cfg.virtualization.podman;
      services.spice.enable = cfg.virtualization.spice;
      services.libvirt.enable = cfg.virtualization.libvirt;
      services.sunshine.enable = cfg.virtualization.sunshine;
    })

    # Cloud tools
    (mkIf cfg.cloud.enable {
      aws.packages.enable = cfg.cloud.aws;
      azure.packages.enable = cfg.cloud.azure;
      google.packages.enable = cfg.cloud.google;
      k8s.packages.enable = cfg.cloud.k8s;
      terraform.packages.enable = cfg.cloud.terraform;
    })

    # Security tools
    (mkIf cfg.security.enable {
      security.onepassword.enable = cfg.security.onepassword;
      security.gnupg.enable = cfg.security.gnupg;
    })

    # Networking
    (mkIf cfg.networking.enable {
      vpn.tailscale.enable = cfg.networking.tailscale;
    })

    # AI tools
    (mkIf cfg.ai.enable {
      ai.ollama.enable = cfg.ai.ollama;
    })

    # Programs
    (mkIf true {
      programs.lazygit.enable = cfg.programs.lazygit;
      programs.thunderbird.enable = cfg.programs.thunderbird;
      programs.obsidian.enable = cfg.programs.obsidian;
      programs.office.enable = cfg.programs.office;
      programs.webcam.enable = cfg.programs.webcam;
      services.print.enable = cfg.programs.print;
    })

    # Media tools
    (mkIf true {
      media.droidcam.enable = cfg.media.droidcam;
    })
  ];
}
