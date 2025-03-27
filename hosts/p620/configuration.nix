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
    # ../../modules/services/tabby/default.nix
  ];
  media.droidcam.enable = lib.mkForce true;
  aws.packages.enable = lib.mkForce true;
  azure.packages.enable = lib.mkForce true;
  cloud-tools.packages.enable = lib.mkForce true;
  steampipe.packages.enable = lib.mkForce true;
  google.packages.enable = lib.mkForce true;
  k8s.packages.enable = lib.mkForce true;
  # openshift.packages.enable = true;
  terraform.packages.enable = lib.mkForce true;

  # Development tools
  ansible.development.enable = lib.mkForce true;
  cargo.development.enable = lib.mkForce true;
  github.development.enable = lib.mkForce true;
  go.development.enable = lib.mkForce true;
  java.development.enable = lib.mkForce true;
  lua.development.enable = lib.mkForce true;
  nix.development.enable = lib.mkForce true;
  shell.development.enable = lib.mkForce true;
  devshell.development.enable = lib.mkForce true;
  python.development.enable = lib.mkForce true;
  nodejs.development.enable = lib.mkForce true;

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

  # Productivity tools
  programs.streamcontroller.enable = lib.mkForce true;

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
    pkgs-unstable.rocmPackages.llvm.libcxx
    pkgs-unstable.via
    pkgs-unstable.looking-glass-client
    pkgs-unstable.scream
  ];

  services.udev.packages = [pkgs-unstable.via];
  hardware.keyboard.qmk.enable = true;

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

  systemd.user.services.scream-ivshmem = {
    enable = true;
    description = "Scream IVSHMEM";
    serviceConfig = {
      ExecStart = "${pkgs-unstable.scream}/bin/scream-ivshmem-pulse /dev/shm/scream";
      Restart = "always";
    };
    wantedBy = ["multi-user.target"];
    requires = ["pulseaudio.service"];
  };

  users.defaultUserShell = pkgs.zsh;

  environment.shells = with pkgs; [zsh];

  programs.zsh.enable = true;

  environment.sessionVariables = {
    FLAKE = "/home/olafkfreund/.config/nixos";
  };

  users.users.${username} = {
    isNormalUser = true;
    description = "Olaf K-Freund";
    extraGroups = ["networkmanager" "openrazer" "libvirtd" "wheel" "docker" "podman" "video" "scanner" "lp" "dialout" "lxd" "incus-admin"];
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
  hardware.flipperzero.enable = true;
  services.playerctld.enable = true;
  services.fwupd.enable = true;
  services.ollama.acceleration = lib.mkForce "rocm";
  # Xs4monly4e!!services.ollama.package = lib.mkForce pkgs-unstable.ollama-rocm;
  services.ollama.rocmOverrideGfx = lib.mkForce "11.0.0";
  services.ollama.environmentVariables.HCC_AMDGPU_TARGET = lib.mkForce "gfx1100";
  services.ollama.environmentVariables.ROC_ENABLE_PRE_VEGA = lib.mkForce "1";
  services.ollama.environmentVariables.HSA_OVERRIDE_GFX_VERSION = lib.mkForce "11.0.0";
  # services.ollama.environmentVariables.OLLAMA_LLM_LIBRARY = lib.mkForce "rocm_v6";
  networking.firewall.enable = false;
  networking.nftables.enable = true;
  networking.timeServers = ["pool.ntp.org"];
  nixpkgs.config.permittedInsecurePackages = ["olm-3.2.16"];
  system.stateVersion = "24.11";
}
