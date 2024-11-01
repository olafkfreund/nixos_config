{
  pkgs,
  lib,
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
    ./nixos/intel.nix
    ../../modules/default.nix
    ../../modules/development/default.nix
    ../../modules/system-tweaks/kernel-tweaks/32GB-SYSTEM/32GB-SYSTEM.nix
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
  ai.ollama.enable = lib.mkForce false;

  # Printing
  services.print.enable = lib.mkForce false;

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
  programs.sway = {
    enable = true;
    xwayland.enable = true;
    wrapperFeatures.gtk = true; # so that gtk works properly
    extraPackages = with pkgs; [
      swaylock
      swayidle
      swaycons
      wl-clipboard
      wf-recorder
      wlr-which-key
      wlr-randr
      grim
      slurp
      dmenu # Dmenu is the default in the config but i recommend wofi since its wayland native
      foot
    ];
    extraSessionCommands = ''
      export SDL_VIDEODRIVER=wayland
      export QT_QPA_PLATFORM=wayland
      export QT_WAYLAND_DISABLE_WINDOWDECORATION="1"
      export _JAVA_AWT_WM_NONREPARENTING=1
      # export WLR_BACKENDS="headless,libinput"
      # export WLR_LIBINPUT_NO_DEVICES=1
      export MOZ_ENABLE_WAYLAND=1
    '';
  };

  security.wrappers.sunshine = {
    owner = "root";
    group = "root";
    capabilities = "cap_sys_admin+p";
    source = "${pkgs.sunshine}/bin/sunshine";
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
    FLAKE = "/home/${username}/.config/nixos";
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
  hardware.keyboard.zsa.enable = true;

  services.ollama.acceleration = "rocm";

  hardware.nvidia-container-toolkit.enable = false;

  networking.firewall.enable = false;
  networking.nftables.enable = true;
  networking.timeServers = ["pool.ntp.org"];
  system.stateVersion = "24.11";
}
