{pkgs, lib, ...}: {
  imports = [
    ./nixos/hardware-configuration.nix
    ./nixos/power.nix
    ./nixos/boot.nix
    ./nixos/i18n.nix
    ./themes/stylix.nix
    ./nixos/greetd.nix
    ./nixos/intel.nix
    ../../home/desktop/sway/default.nix
    ../../modules/default.nix
    ../../modules/system-tweaks/kernel-tweaks/32GB-SYSTEM/32GB-SYSTEM.nix
  ];
  services.xserver = {
    enable = true;
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
    extraGroups = ["networkmanager" "openrazer" "wheel" "docker" "podman" "video" "scanner" "lp" "lxd" "incus-admin"];
    shell = pkgs.zsh;
    packages = with pkgs; [
      vim
      wally-cli
    ];
  };
  hardware.keyboard.zsa.enable = true;
 
  services.ollama.acceleration = "rocm";
  
  hardware.nvidia-container-toolkit.enable = false;

  networking.firewall.enable = false;
  networking.nftables.enable = true;
  networking.timeServers = ["pool.ntp.org"];
  system.stateVersion = "24.11";
}
