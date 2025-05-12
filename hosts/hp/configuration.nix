{
  pkgs,
  lib,
  inputs,
  ...
}: let
  vars = import ./variables.nix;
in {
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
    ../common/hyprland.nix
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
    videoDrivers = ["${vars.gpu}"];
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

  # Set a timeout for network-online.target to prevent long delays
  systemd.network.wait-online.timeout = 10;

  # Network configuration - using systemd-networkd instead of NetworkManager
  networking = {
    networkmanager.enable = false;
    hostName = vars.hostName;
    nameservers = vars.nameservers;
    useDHCP = false;
    useNetworkd = true;
    # Enable resolved for DNS resolution
    useHostResolvConf = false;
  };

  # Enable systemd-resolved for DNS resolution with systemd-networkd
  services.resolved = {
    enable = true;
    dnssec = "true";
    fallbackDns = vars.nameservers;
  };

  users.defaultUserShell = pkgs.zsh;
  environment.shells = with pkgs; [zsh];
  programs.zsh.enable = true;
  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    NH_FLAKE = vars.paths.flakeDir;
  };

  users.users.${vars.username} = {
    isNormalUser = true;
    description = vars.fullName;
    extraGroups = vars.userGroups;
    shell = pkgs.zsh;
    packages = with pkgs; [
      vim
      wally-cli
    ];
  };
  hardware.keyboard.zsa.enable = true;
  services.ollama.acceleration = vars.acceleration;
  hardware.nvidia-container-toolkit.enable = true;
  networking.firewall.enable = false;
  networking.nftables.enable = true;
  networking.timeServers = ["pool.ntp.org"];
  system.stateVersion = "24.11";
}
