{ pkgs, ... }: {
  imports = [
    ../common/base-home.nix
    # Add serveruser-specific modules here
  ];

  # Serveruser-specific configuration for P510
  home.packages = with pkgs; [
    # Server management tools
    htop
    iotop
    ncdu
    tmux
    screen
    rsync

    # Network tools
    nmap
    netcat
    tcpdump
    wireshark

    # System monitoring
    lm_sensors
    smartmontools
  ];

  # Server-specific programs
  programs = {
    git = {
      enable = true;
      userName = "Server User";
      userEmail = "serveruser@example.com";
    };

    # Enhanced shell for server management
    zsh.enable = true;

    # Terminal multiplexer
    tmux.enable = true;
  };

  # Server-specific services
  services = {
    # Add any server-specific services here
  };
}
