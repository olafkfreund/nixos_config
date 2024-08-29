{
  pkgs,
  pkgs-stable,
  lib,
  inputs,
  config,
  options,
  ...
}: {
  imports = [
    ./nixos/hardware-configuration.nix
    ./nixos/screens.nix
    ./nixos/power.nix
    ./nixos/boot.nix
    ./nixos/nvidia.nix
    ./nixos/i18n.nix
    ./nixos/hosts.nix
    ./nixos/envvar.nix
    ./nixos/greetd.nix
    ./themes/stylix.nix
    ../../modules/default.nix
    ../../modules/laptops.nix
    ../../modules/development/default.nix
  ];
  
  aws.packages.enable = true;
  azure.packages.enable = true;
  cloud-tools.packages.enable = true;
  google.packages.enable = true;
  k8s.packages.enable = true;
  # openshift.packages.enable = true;
  terraform.packages.enable = true;

  # Development tools
  ansible.development.enable = true;
  cargo.development.enable = true;
  github.development.enable = true;
  go.development.enable = true;
  java.development.enable = true;
  lua.development.enable = true;
  nix.development.enable = true;
  shell.development.enable = true;
  devshell.development.enable = true;
  python.development.enable = true;
  nodejs.development.enable = true;

  # Git tools
  programs.lazygit.enable = lib.mkForce true;
  programs.thunderbird.enable = lib.mkForce true;
  programs.obsidian.enable = lib.mkForce true;
  programs.office.enable = lib.mkForce true;
  programs.webcam.enable = lib.mkForce true;
  
  # Virtualization tools
  services.docker.enable = lib.mkForce true;
  services.incus.enable = lib.mkForce true;
  services.podman.enable = lib.mkForce true;
  services.spice.enable = lib.mkForce true;
  services.libvirt.enable = lib.mkForce true;



  services = {
    xserver = {
      enable = true;
      desktopManager.gnome.enable = true;
      displayManager.xserverArgs = [
        "-nolisten tcp"
        "-dpi 96"
      ];
      videoDrivers = ["nvidia"];
    };
  };
  environment.systemPackages = [
    inputs.zen-browser.packages."${pkgs.system}".default
  ];

  # Disable network wait services to improve boot time
  systemd.services = {
    NetworkManager-wait-online = {
      enable = lib.mkForce false;
      wantedBy = lib.mkForce [];
    };
    systemd-networkd-wait-online = {
      enable = lib.mkForce false;
      wantedBy = lib.mkForce [];
    };
  };

  # Set a timeout for network-online.target to prevent long delays
  systemd.network.wait-online.timeout = 10;

  networking.networkmanager.enable = true;
  networking.hostName = "razer";
  networking = {
    useDHCP = false;
    useNetworkd = true;
  };

  # Network configuration
  systemd.network = {
    networks = {
      "20-wired" = {
        matchConfig.Name = "en*";
        networkConfig = {
          DHCP = "yes";
          MulticastDNS = true;
        };
      };
      "25-wireless" = {
        matchConfig.Name = "wl*";
        networkConfig = {
          DHCP = "yes";
          MulticastDNS = true;
        };
      };
    };
  };

  users.defaultUserShell = pkgs.zsh;

  environment.shells = with pkgs; [zsh];

  programs.zsh.enable = true;

  environment.sessionVariables = {
    FLAKE = "/home/olafkfreund/.config/nixos";
    GBM_BACKEND = "nvidia-drm";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
    NVD_BACKEND = "direct";
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

  services.playerctld.enable = true;
  
  services.ollama.acceleration = "cuda";
  
  hardware.nvidia-container-toolkit.enable = true;
  
  networking.firewall.enable = false;
  networking.nftables.enable = true;
  networking.timeServers = ["pool.ntp.org"];

  system.stateVersion = "24.11";
}
