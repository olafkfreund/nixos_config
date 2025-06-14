{
  config,
  lib,
  pkgs,
  ...
}: {
  imports = [
    ./nix.nix
    ./users.nix
    ./networking.nix
    ./security.nix
    ./system.nix
  ];

  # Core system configuration that should always be enabled
  config = {
    # Enable flakes and new nix command
    nix.settings = {
      experimental-features = ["nix-command" "flakes"];
      auto-optimise-store = true;
      trusted-users = ["root" "@wheel"];
    };

    # Basic system packages that should always be available
    environment.systemPackages = with pkgs; [
      wget
      curl
      git
      vim
      htop
      tree
      file
      which
      unzip
      zip
      tar
      gzip
    ];

    # Enable NetworkManager by default
    networking.networkmanager.enable = lib.mkDefault true;

    # Basic security settings
    security.sudo.wheelNeedsPassword = lib.mkDefault false;

    # Enable zsh
    programs.zsh.enable = true;
  };
}
