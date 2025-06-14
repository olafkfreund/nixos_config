{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.custom.server;
in {
  options.custom.server = {
    enable = lib.mkEnableOption "server configuration";

    ssh = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable SSH server";
      };

      port = lib.mkOption {
        type = lib.types.int;
        default = 22;
        description = "SSH port";
      };

      allowedUsers = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Users allowed to SSH";
      };
    };

    firewall = {
      strict = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable strict firewall rules";
      };

      allowedTCPPorts = lib.mkOption {
        type = lib.types.listOf lib.types.int;
        default = [];
        description = "Additional TCP ports to allow";
      };

      allowedUDPPorts = lib.mkOption {
        type = lib.types.listOf lib.types.int;
        default = [];
        description = "Additional UDP ports to allow";
      };
    };

    monitoring = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable monitoring stack";
      };
    };

    backup = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable backup services";
      };
    };
  };

  imports = [
    ../modules/server/ssh.nix
    ../modules/server/firewall.nix
    ../modules/server/monitoring.nix
    ../modules/server/backup.nix
  ];

  config = lib.mkIf cfg.enable {
    # Enable base system
    custom.base.enable = true;

    # Server-specific optimizations
    boot = {
      # Optimize for servers
      kernel.sysctl = {
        # Network optimizations
        "net.core.default_qdisc" = "fq";
        "net.ipv4.tcp_congestion_control" = "bbr";
        "net.ipv4.tcp_fastopen" = 3;

        # Memory management
        "vm.swappiness" = 10;
        "vm.dirty_ratio" = 15;
        "vm.dirty_background_ratio" = 5;
      };

      # Disable unnecessary services
      blacklistedKernelModules = [
        "snd_hda_intel"
        "snd_hda_codec_hdmi"
        "bluetooth"
      ];
    };

    # SSH configuration
    services.openssh = lib.mkIf cfg.ssh.enable {
      enable = true;
      ports = [cfg.ssh.port];
      settings = {
        PasswordAuthentication = false;
        PermitRootLogin = "no";
        X11Forwarding = false;
        AllowUsers = cfg.ssh.allowedUsers;
      };
    };

    # Firewall configuration
    networking.firewall = {
      enable = true;
      allowPing = true;
      allowedTCPPorts = [cfg.ssh.port] ++ cfg.firewall.allowedTCPPorts;
      allowedUDPPorts = cfg.firewall.allowedUDPPorts;

      # Strict rules
      extraCommands = lib.mkIf cfg.firewall.strict ''
        # Drop invalid packets
        iptables -A INPUT -m conntrack --ctstate INVALID -j DROP

        # Rate limit SSH connections
        iptables -A INPUT -p tcp --dport ${toString cfg.ssh.port} -m conntrack --ctstate NEW -m recent --set
        iptables -A INPUT -p tcp --dport ${toString cfg.ssh.port} -m conntrack --ctstate NEW -m recent --update --seconds 60 --hitcount 4 -j DROP
      '';
    };

    # System monitoring
    environment.systemPackages = with pkgs; [
      htop
      iotop
      iftop
      tcpdump
      wireshark-cli
      sysstat
      lsof
      smartmontools
    ];

    # Enable fail2ban for SSH protection
    services.fail2ban = {
      enable = cfg.ssh.enable;
      jails = {
        sshd = {
          enabled = true;
          filter = "sshd";
          action = "iptables[name=SSH, port=${toString cfg.ssh.port}, protocol=tcp]";
          logpath = "/var/log/auth.log";
          maxretry = 3;
          bantime = 3600;
        };
      };
    };

    # Automatic security updates
    system.autoUpgrade = {
      enable = true;
      dates = "04:00";
      randomizedDelaySec = "45min";
      allowReboot = false;
    };

    # Log management
    services.journald.extraConfig = ''
      SystemMaxUse=1G
      SystemMaxFileSize=100M
      MaxRetentionSec=1month
    '';

    # Disable unnecessary services
    services.avahi.enable = false;
    services.printing.enable = false;
    hardware.bluetooth.enable = false;
    hardware.pulseaudio.enable = false;
    services.pipewire.enable = false;

    # Disable GUI if not explicitly enabled
    services.xserver.enable = lib.mkDefault false;

    # Enable monitoring if requested
    custom.server.monitoring.enable = cfg.monitoring.enable;
    custom.server.backup.enable = cfg.backup.enable;
  };
}
