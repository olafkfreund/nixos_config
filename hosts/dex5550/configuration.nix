{pkgs, ...}: {
  imports = [
    ./hardware-configuration.nix
    ./power.nix
    ./boot.nix
    ./i18n.nix
    ./stylix.nix
    ./greetd.nix
    ./intel.nix
    ../../modules/default.nix
    ../../modules/system-tweaks/kernel-tweaks/32GB-SYSTEM/32GB-SYSTEM.nix
  ];
  services.xserver = {
    enable = true;
    desktopManager.gnome.enable = true;
    displayManager.xserverArgs = [
      "-nolisten tcp"
      "-dpi 96"
    ];
  };

  systemd.services.NetworkManager-wait-online.enable = lib.mkForce false;
  systemd.services.systemd-networkd-wait-online.enable = lib.mkForce false;

  networking.networkmanager.enable = true;
  networking.hostName = "dex5550";
  networking = {
    useDHCP = false;
    useNetworkd = true;
  };

  

  systemd.network = {
    networks = {
      "enp1s0" = {
        name = "enp1s0";
        DHCP = "ipv4";
        networkConfig = {
          MulticastDNS = true;
        };
      };
      "wlp2s0" = {
        name = "wlp2s0";
        DHCP = "ipv4";
        networkConfig = {
          MulticastDNS = true;
        };
      };

    };
  };

  users.defaultUserShell = pkgs.zsh;

  environment.shells = with pkgs; [zsh];

  programs.zsh.enable = true;

  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    FLAKE = "/home/olafkfreund/.config/nixos";
  };

  users.users.olafkfreund = {
    isNormalUser = true;
    description = "Olaf K-Freund";
    extraGroups = ["networkmanager" "openrazer" "wheel" "docker" "video" "scanner" "lp" "lxd" "incus-admin"];
    shell = pkgs.zsh;
    packages = with pkgs; [
      vim
      wally-cli
    ];
  };
  hardware.keyboard.zsa.enable = true;

  networking.firewall.enable = false;
  networking.nftables.enable = true;
  networking.timeServers = ["pool.ntp.org"];
  system.stateVersion = "24.11";
}
