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
    pkgs.rocmPackages.rocm-core
    pkgs.rocmPackages.hip-common
    pkgs.rocmPackages.rccl
    pkgs.rocmPackages.rocrand
    pkgs.rocmPackages.rocblas
    pkgs.rocmPackages.rocfft
    pkgs.rocmPackages.rocsparse
    pkgs.rocmPackages.hipsparse
    pkgs.rocmPackages.rocthrust
    pkgs.rocmPackages.rocprim
    pkgs.rocmPackages.hipcub
    pkgs.rocmPackages.roctracer
    pkgs.rocmPackages.rocfft
    pkgs.rocmPackages.rocsolver
    pkgs.rocmPackages.hipfft
    pkgs.rocmPackages.hipsolver
    pkgs.rocmPackages.hipblas
    pkgs.rocmPackages.rocminfo
    pkgs.rocmPackages.rocm-cmake
    pkgs.rocmPackages.rocm-smi
    pkgs.rocmPackages.rocm-thunk
    pkgs.rocmPackages.rocm-comgr
    pkgs.rocmPackages.rocm-device-libs
    pkgs.rocmPackages.rocm-runtime
    pkgs.rocmPackages.hipify
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
  services.ollama.package = lib.mkForce pkgs-unstable.ollama-rocm;
  services.ollama.rocmOverrideGfx = lib.mkForce "11.0.0";
  services.ollama.environmentVariables.HCC_AMDGPU_TARGET = lib.mkForce "gfx1100";
  services.ollama.environmentVariables.OLLAMA_LLM_LIBRARY = lib.mkForce "rocm_v6";
  networking.firewall.enable = false;
  networking.nftables.enable = true;
  networking.timeServers = ["pool.ntp.org"];

  nixpkgs.config.permittedInsecurePackages = ["olm-3.2.16"];

  system.stateVersion = "24.11";

  nixpkgs.overlays = [
    (self: super: {
      rocm-llvm-libcxx = super.rocm-llvm-libcxx.overrideAttrs (oldAttrs: rec {
        patches =
          oldAttrs.patches
          or []
          ++ [
            /home/olafkfreund/.config/nixos/patches/rocm-llvm-libcxx-6.0.2.patch
          ];
      });
    })
  ];
}
