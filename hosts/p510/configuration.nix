{
  pkgs,
  inputs,
  lib,
  ...
}: {
  imports = [
    # inputs.microvm.nixosModules.host

    ./nixos/hardware-configuration.nix
    ./nixos/power.nix
    ./nixos/boot.nix
    ./nixos/nvidia.nix
    ./nixos/i18n.nix
    ./nixos/envvar.nix
    ./nixos/greetd.nix
    ./nixos/hosts.nix
    ./nixos/mpd.nix
    ./nixos/hosts.nix
    ./themes/stylix.nix
    ./nixos/plex.nix
    ../../modules/server.nix
    ../../modules/default.nix
    ../../modules/development/default.nix
  ];

  # Enable secure DNS with DNS over TLS
  services.secure-dns = {
    enable = true;
    dnssec = "true";
    fallbackProviders = [
      "1.1.1.1#cloudflare-dns.com" # Cloudflare DNS
      "8.8.8.8#dns.google" # Google DNS
    ];
  };

  aws.packages.enable = lib.mkForce false;
  media.droidcam.enable = lib.mkForce true;
  azure.packages.enable = lib.mkForce false;
  cloud-tools.packages.enable = lib.mkForce false;
  steampipe.packages.enable = lib.mkForce false;
  google.packages.enable = lib.mkForce false;
  k8s.packages.enable = lib.mkForce false;
  # openshift.packages.enable = true;
  terraform.packages.enable = lib.mkForce false;

  # Development tools
  ansible.development.enable = lib.mkForce false;
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
  programs.thunderbird.enable = lib.mkForce false;
  programs.obsidian.enable = lib.mkForce false;
  programs.office.enable = lib.mkForce false;
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
  services.print.enable = lib.mkForce false;

  services.xserver = {
    enable = true;
    displayManager.xserverArgs = [
      "-nolisten tcp"
      "-dpi 96"
    ];
    videoDrivers = ["nvidia"];
  };
  programs.streamdeck-ui = {
    enable = true;
    autoStart = true; # optional
  };
  programs.sway = {
    enable = true;
    wrapperFeatures.gtk = true; # so that gtk works properly
    extraPackages = with pkgs; [
      swaylock
      swayidle
      swaycons
      wl-clipboard
      wlr-which-key
      wlr-randr
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
      # export WLR_BACKENDS="headless,libinput"
      # export WLR_LIBINPUT_NO_DEVICES="1"
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
  networking.hostName = "p510";
  networking.nameservers = [
    "8.8.8.8"
    "8.8.4.4"
  ];
  networking = {
    useDHCP = false;
    useNetworkd = true;
  };

  systemd.network = {
    networks = {
      "eno1" = {
        name = "eno1";
        DHCP = "ipv4";
        networkConfig = {
          MulticastDNS = true;
        };
      };
      "wlp8s" = {
        name = "wlp8s*";
        DHCP = "ipv4";
        networkConfig = {
          MulticastDNS = true;
          IPv6AcceptRA = true;
        };
      };
    };
  };

  users.defaultUserShell = pkgs.zsh;

  qt.enable = true;
  qt.platformTheme = "gtk2";
  qt.style = "gtk2";

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
  services.ollama.acceleration = "cuda";
  nixpkgs.config.permittedInsecurePackages = ["olm-3.2.16" "dotnet-sdk-6.0.428"];
  hardware.nvidia-container-toolkit.enable = true;
  networking.firewall.enable = false;
  networking.nftables.enable = true;
  networking.timeServers = ["pool.ntp.org"];
  system.stateVersion = "24.11";
}
