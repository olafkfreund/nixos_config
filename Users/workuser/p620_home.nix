{ pkgs, ... }: {
  imports = [
    ../common/base-home.nix
    # Add workuser-specific modules here
  ];

  # Workuser-specific configuration for P620
  home.packages = with pkgs; [
    # Work-specific packages
    # libreoffice  # Disabled: use online alternatives
    thunderbird
    teams-for-linux
    zoom-us
    remmina

    # Development tools for work
    vscode
    git
    curl
    wget
  ];

  # Work-specific programs
  programs = {
    firefox.enable = true;
    git = {
      enable = true;
      userName = "Work User";
      userEmail = "workuser@example.com";
    };
  };

  # Work-specific services
  services = {
    # Enable automatic updates for work environment
    # Add any work-specific services here
  };
}
