{
  pkgs,
  lib,
  inputs,
  username,
  pkgs-unstable,
  ...
}: {
  imports = [
    ./nixos/hardware-configuration.nix
    ./nixos/screens.nix
    ./nixos/power.nix
    ./nixos/boot.nix
    ./nixos/amd.nix
    ./nixos/i18n.nix
    ./nixos/hosts.nix
    ./nixos/envvar.nix
    ./nixos/greetd.nix
    ./nixos/mpd.nix
    ./themes/stylix.nix
    ../../modules/default.nix
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
  services.incus.enable = lib.mkForce false;
  services.podman.enable = lib.mkForce true;
  services.spice.enable = lib.mkForce true;
  services.libvirt.enable = lib.mkForce true;
  services.sunshine.enable = lib.mkForce true;

  # Password management
  security.onepassword.enable = lib.mkForce true;
  security.gnupg.enable = lib.mkForce true;

  # VPN
  vpn.tailscale.enable = lib.mkForce true;

  # AI
  ai.ollama.enable = lib.mkForce true;

  # Printing
  services.print.enable = lib.mkForce true;

  # # security
  # security.intune-portal.enable = lib.mkForce false;

  services = {
    xserver = {
      enable = true;
      desktopManager.gnome.enable = true;
      displayManager.xserverArgs = [
        "-nolisten tcp"
        "-dpi 96"
      ];
    };
  };
  services.xserver.videoDrivers = ["amdgpu"];
  environment.systemPackages = [
    inputs.zen-browser.packages."${pkgs.system}".default
    # pkgs-unstable.rocmPackages.rocm-core
    # pkgs-unstable.rocmPackages.hip-common
    # pkgs-unstable.rocmPackages.rccl
    # # pkgs-unstable.rocmPackages.rocrand
    # # pkgs-unstable.rocmPackages.rocblas
    # # pkgs-unstable.rocmPackages.rocfft
    # # pkgs-unstable.rocmPackages.rocsparse
    # # pkgs-unstable.rocmPackages.hipsparse
    # pkgs-unstable.rocmPackages.rocthrust
    # pkgs-unstable.rocmPackages.rocprim
    # pkgs-unstable.rocmPackages.hipcub
    # # pkgs-unstable.rocmPackages.roctracer
    # # pkgs-unstable.rocmPackages.rocfft
    # # pkgs-unstable.rocmPackages.rocsolver
    # # pkgs-unstable.rocmPackages.hipfft
    # # pkgs-unstable.rocmPackages.hipsolver
    # # pkgs-unstable.rocmPackages.hipblas
    # pkgs-unstable.rocmPackages.rocminfo
    # pkgs-unstable.rocmPackages.rocm-cmake
    # pkgs-unstable.rocmPackages.rocm-smi
    # pkgs-unstable.rocmPackages.rocm-thunk
    # pkgs-unstable.rocmPackages.rocm-comgr
    # pkgs-unstable.rocmPackages.rocm-device-libs
    # pkgs-unstable.rocmPackages.rocm-runtime
    # pkgs-unstable.rocmPackages.hipify
    pkgs-unstable.rocmPackages.llvm.libcxx
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
  networking.hostName = "p620";
  networking.nameservers = [
    "1.1.1.1"
    "8.8.8.8"
  ];
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
  # programs.sway = {
  #   extraSessionCommands = ''
  #     export WLR_RENDERER=vulkan
  #     export WLR_DRM_DEVICES=/dev/dri/card2
  #   '';
  # };

  users.defaultUserShell = pkgs.zsh;

  environment.shells = with pkgs; [zsh];

  programs.zsh.enable = true;

  environment.sessionVariables = {
    FLAKE = "/home/olafkfreund/.config/nixos";
  };

  users.users.${username} = {
    isNormalUser = true;
    description = "Olaf K-Freund";
    extraGroups = ["networkmanager" "openrazer" "wheel" "docker" "podman" "video" "scanner" "lp" "lxd" "incus-admin"];
    shell = pkgs.zsh;
    packages = with pkgs; [
      vim
      wally-cli
    ];
  };
  services.nfs.server.enable = true;
  services.nfs.server.exports = ''
    /mnt/data         *(rw,fsid=0,no_subtree_check)
  '';
  fileSystems."/mnt/media" = {
    device = "192.168.1.127:/mnt/media";
    fsType = "nfs";
    options = ["x-systemd.automount" "noauto"];
  };
  services.playerctld.enable = true;
  services.fwupd.enable = true;
  services.ollama.acceleration = lib.mkForce "rocm";
  services.ollama.package = lib.mkForce pkgs.ollama-rocm;
  services.ollama.rocmOverrideGfx = lib.mkForce "11.0.0";
  services.ollama.environmentVariables.HCC_AMDGPU_TARGET = lib.mkForce "gfx1100";
  services.ollama.environmentVariables.OLLAMA_LLM_LIBRARY = lib.mkForce "rocm_v6";
  networking.firewall.enable = false;
  networking.nftables.enable = true;
  networking.timeServers = ["pool.ntp.org"];
  nixpkgs.config.permittedInsecurePackages = ["olm-3.2.16"];
  system.stateVersion = "24.11";
}
