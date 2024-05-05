{ self, config, pkgs, ... }:

{
    imports =
      [ 
        ./hardware-configuration.nix
        ./screens.nix
        ./boot.nix
        ./power.nix
        ./nvidia.nix
        ./i18n.nix
        ./envvar.nix
        ../../modules/default.nix
        ../../modules/services/thinkpad/thinkpad.nix
       
      ];

  networking.hostName = "work-lx"; # Define your hostname.
  networking.networkmanager.enable = true;
  networking.firewall.enable = false;
  networking = {
    useDHCP = false;
    useNetworkd = true;
  };

  systemd.network = {
    networks = {
      "wlp0s20f3" = {
        name = "wlp0s20f3";
        DHCP = "ipv4";
        networkConfig = {
          MulticastDNS = true;
        };
      };
      "enp86s0u1u4u5" = {
        name = "enp86s0u1u4u5";
        DHCP = "ipv4";
        networkConfig = {
          MulticastDNS = true;
        };
      };
    };
  };
  
  

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.olafkfreund = {
    isNormalUser = true;
    description = "Olaf K-Freund";
    extraGroups = [ "networkmanager" "openrazer" "wheel" "docker" "podman" "video" "scanner" "lp"];
    packages = with pkgs; [
      kate
      kitty
      neovim
      vim
    ];
  };

  environment.systemPackages = with pkgs; [
    adwaita-qt# For sddm to function properly
    bibata-cursors
    nix-prefetch-scripts
    polkit
    libsForQt5.polkit-kde-agent
    libsForQt5.qt5.qtgraphicaleffects
    # sddm-themes.sugar-dark
    # sddm-themes.astronaut

    wget
    git
    curl
    file
    lsof
    lshw
    openssl
    ripgrep
    tcpdump
    tree
    unzip
    which
    gcc
    gdb
    go
    gnumake
    ispell
    aspell
    jq
    sqlite
    z3
    # Development
    nil # Nix lsp
    devbox # faster nix-shells
    shellify # faster nix-shells
    github-desktop
    polychromatic
  ];
  #


  nixpkgs.config.allowUnfree = true;
  system.stateVersion = "24.05";
}
