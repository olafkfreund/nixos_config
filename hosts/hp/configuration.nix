{
  pkgs,
  lib,
  inputs,
  ...
}: {
  imports = [
    inputs.microvm.nixosModules.host

    ./nixos/hardware-configuration.nix
    ./nixos/power.nix
    ./nixos/boot.nix
    ./nixos/nvidia.nix
    ./nixos/i18n.nix
    ./nixos/envvar.nix
    ./nixos/greetd.nix
    ./nixos/hosts.nix
    ./themes/stylix.nix
    ../../modules/server.nix
    ../../modules/default.nix
    ../../modules/development/default.nix
    # ./guests/k3sserver.nix
  ];

  aws.packages.enable = lib.mkForce false;
  media.droidcam.enable = lib.mkForce true;
  azure.packages.enable = lib.mkForce false;
  cloud-tools.packages.enable = lib.mkForce false;
  google.packages.enable = lib.mkForce false;
  k8s.packages.enable = lib.mkForce true;
  # openshift.packages.enable = true;
  terraform.packages.enable = lib.mkForce false;

  # Development tools
  ansible.development.enable = lib.mkForce false;
  cargo.development.enable = false;
  github.development.enable = true;
  go.development.enable = true;
  java.development.enable = lib.mkForce false;
  lua.development.enable = true;
  nix.development.enable = true;
  shell.development.enable = true;
  devshell.development.enable = true;
  python.development.enable = true;
  nodejs.development.enable = lib.mkForce true;

  # Git tools
  programs.lazygit.enable = lib.mkForce true;
  programs.thunderbird.enable = lib.mkForce false;
  programs.obsidian.enable = lib.mkForce false;
  programs.office.enable = lib.mkForce false;
  programs.webcam.enable = lib.mkForce false;

  # Virtualization tools
  services.docker.enable = lib.mkForce true;
  services.incus.enable = lib.mkForce false;
  services.podman.enable = lib.mkForce true;
  services.spice.enable = lib.mkForce true;
  services.libvirt.enable = lib.mkForce true;
  services.sunshine.enable = lib.mkForce true;

  # Password management
  security.onepassword.enable = lib.mkForce false;
  security.gnupg.enable = lib.mkForce true;

  # VPN
  vpn.tailscale.enable = lib.mkForce true;

  # AI
  ai.ollama.enable = lib.mkForce false;

  # Printing
  services.print.enable = lib.mkForce false;

  services.xserver = {
    enable = true;
    displayManager.xserverArgs = [
      "-nolisten tcp"
      "-dpi 96"
    ];
    videoDrivers = ["nvidia"];
  };

  programs.sway = {
    enable = true;
    wrapperFeatures.gtk = true; # so that gtk works properly
    extraPackages = with pkgs; [
      swaylock
      swayidle
      wl-clipboard
      grim
      slurp
      foot
      dmenu # Dmenu is the default in the config but i recommend wofi since its wayl
      zfs
      lvm2
    ];
    extraSessionCommands = ''
      export SDL_VIDEODRIVER=wayland
      export QT_QPA_PLATFORM=wayland
      export QT_WAYLAND_DISABLE_WINDOWDECORATION="1"
      export _JAVA_AWT_WM_NONREPARENTING=1
      export MOZ_ENABLE_WAYLAND=1
      export WLR_BACKENDS="headless,libinput"
      export WLR_LIBINPUT_NO_DEVICES="1"
    '';
  };

  security.wrappers.sunshine = {
    owner = "root";
    group = "root";
    capabilities = "cap_sys_admin+p";
    source = "${pkgs.sunshine}/bin/sunshine";
  };

  systemd.services.NetworkManager-wait-online.enable = lib.mkForce false;
  systemd.services.systemd-networkd-wait-online.enable = lib.mkForce false;

  networking.networkmanager.enable = true;
  networking.hostName = "hp";
  networking = {
    useDHCP = false;
    useNetworkd = true;
  };

  systemd.network = {
    netdevs."br0" = {
      netdevConfig = {
        Name = "br0";
        Kind = "bridge";
      };
    };
    networks = {
      "eno1" = {
        name = "eno1";
        DHCP = "ipv4";
        networkConfig = {
          MulticastDNS = true;
          Address = ["192.168.1.246/24"];
          Gateway = "192.168.1.254";
          DNS = ["8.8.8.8" "8.8.4.4"];
          IPv6AcceptRA = false;
        };
      };
      "enp8s0f0" = {
        name = "enp8s0f0";
        DHCP = "ipv4";
        networkConfig = {
          MulticastDNS = true;
        };
      };
      "enp8s0f1" = {
        name = "enp8s0f1";
        DHCP = "ipv4";
        networkConfig = {
          MulticastDNS = true;
        };
      };
      "10-lan" = {
        matchConfig.Name = ["enp8s*" "vm-*"];
        networkConfig = {
          Bridge = "br0";
        };
      };
      "10-lan-bridge" = {
        matchConfig.Name = "br0";
        networkConfig = {
          Address = ["192.168.1.83/24"];
          Gateway = "192.168.1.254";
          DNS = ["8.8.8.8" "8.8.4.4"];
          IPv6AcceptRA = false;
        };
        linkConfig.RequiredForOnline = "routable";
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
  services.ollama.acceleration = "cuda";
  hardware.nvidia-container-toolkit.enable = true;
  networking.firewall.enable = false;
  networking.nftables.enable = true;
  networking.timeServers = ["pool.ntp.org"];
  system.stateVersion = "24.11";
}
