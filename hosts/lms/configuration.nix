{
  pkgs,
  lib,
  inputs,
  username,
  ...
}: {
  imports = [
    ./nixos/hardware-configuration.nix
    ./nixos/power.nix
    ./nixos/boot.nix
    ./nixos/i18n.nix
    ./themes/stylix.nix
    ./nixos/greetd.nix
    ../../modules/default.nix
    ../../modules/development/default.nix
    ../../modules/system-tweaks/kernel-tweaks/32GB-SYSTEM/32GB-SYSTEM.nix
    ./nixos/intel.nix
    ./services/default.nix
  ];

  aws.packages.enable = lib.mkForce false;
  azure.packages.enable = lib.mkForce false;
  cloud-tools.packages.enable = lib.mkForce false;
  google.packages.enable = lib.mkForce false;
  k8s.packages.enable = lib.mkForce false;
  # openshift.packages.enable = true;
  terraform.packages.enable = lib.mkForce false;

  # Development tools
  ansible.development.enable = lib.mkForce false;
  cargo.development.enable = lib.mkForce true;
  github.development.enable = lib.mkForce true;
  go.development.enable = lib.mkForce true;
  java.development.enable = lib.mkForce false;
  lua.development.enable = lib.mkForce true;
  nix.development.enable = lib.mkForce true;
  shell.development.enable = lib.mkForce true;
  devshell.development.enable = lib.mkForce true;
  python.development.enable = lib.mkForce true;
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
  security.onepassword.enable = lib.mkForce true;
  security.gnupg.enable = lib.mkForce true;

  # VPN
  vpn.tailscale.enable = lib.mkForce true;

  # AI
  ai.ollama.enable = lib.mkForce false;

  # Printing
  services.print.enable = lib.mkForce true;

  systemd.network.wait-online.timeout = 10;

  networking = {
    networkmanager.enable = false;
    hostName = "lms";
    nameservers = [
      "8.8.8.8"
      "8.8.4.4"
    ];
    useDHCP = false;
    useNetworkd = true;
    # Enable resolved for DNS resolution
    useHostResolvConf = false;
  };

  # Enable systemd-resolved for DNS resolution with systemd-networkd
  services.resolved = {
    enable = true;
    dnssec = "true";
    fallbackDns = [
      "8.8.8.8"
      "8.8.4.4"
    ];
  };

  # Configure systemd-networkd for your network interfaces
  systemd.network = {
    enable = true;
    networks = {
      "20-wired" = {
        matchConfig.Name = "en*";
        networkConfig = {
          MulticastDNS = true;
          DHCP = "ipv4";
          IPv6AcceptRA = true;
        };
        # Higher priority for wired connection
        dhcpV4Config = {
          RouteMetric = 10;
        };
      };
    };
  };

  services.xserver = {
    enable = true;
    desktopManager.gnome.enable = true;
    displayManager.xserverArgs = [
      "-nolisten tcp"
      "-dpi 96"
    ];
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

  users.defaultUserShell = pkgs.zsh;

  environment.shells = with pkgs; [zsh];

  programs.zsh.enable = true;

  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    NH_FLAKE = "/home/olafkfreund/.config/nixos";
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

  services.ollama.acceleration = "";

  hardware.nvidia-container-toolkit.enable = false;

  networking.firewall.enable = false;
  networking.nftables.enable = true;
  networking.timeServers = ["pool.ntp.org"];
  system.stateVersion = "24.11";
}
