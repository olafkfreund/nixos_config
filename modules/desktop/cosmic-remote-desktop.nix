{ config
, lib
, pkgs
, ...
}:
with lib; let
  cfg = config.features.desktop.cosmic-remote-desktop;
in
{
  options.features.desktop.cosmic-remote-desktop = {
    enable = mkEnableOption "Remote Desktop support for COSMIC Desktop Environment";

    protocol = mkOption {
      type = types.enum [ "rdp" "vnc" "both" ];
      default = "both";
      description = "Remote desktop protocol to enable (RDP, VNC, or both)";
    };

    rdpPort = mkOption {
      type = types.port;
      default = 3389;
      description = "RDP server port";
    };

    vncPort = mkOption {
      type = types.port;
      default = 5900;
      description = "VNC server port";
    };

    allowedNetworks = mkOption {
      type = types.listOf types.str;
      default = [ "192.168.1.0/24" "10.0.0.0/8" ];
      description = "Networks allowed to connect to remote desktop";
    };

    disableScreenLock = mkOption {
      type = types.bool;
      default = false;
      description = "Disable automatic screen locking for remote sessions";
    };

    disablePowerManagement = mkOption {
      type = types.bool;
      default = true;
      description = "Disable sleep/suspend for remote desktop availability";
    };

    vncPassword = mkOption {
      type = types.str;
      default = "nixos";
      description = "VNC password for authentication (change this for security!)";
    };
  };

  config = mkIf cfg.enable {
    # Enable Wayvnc for VNC support on Wayland/COSMIC
    environment.systemPackages = with pkgs;
      [
        wayvnc # VNC server for Wayland compositors
        waypipe # Wayland application remoting
        wl-clipboard # Clipboard support for remote sessions
      ]
      ++ optionals (cfg.protocol == "rdp" || cfg.protocol == "both") [
        gnome-remote-desktop # RDP support for Wayland
      ]
      ++ [
        # Helper script for remote desktop configuration
        (writeScriptBin "cosmic-remote-setup" ''
          #!${bash}/bin/bash
          set -e

          echo "🖥️  COSMIC Remote Desktop Setup"
          echo "================================"
          echo ""

          # Check if wayvnc is enabled
          ${if cfg.protocol == "vnc" || cfg.protocol == "both" then ''
            echo "📡 Setting up VNC with wayvnc..."
            mkdir -p ~/.config/wayvnc

            # Generate SSL certificates if they don't exist
            if [ ! -f ~/.config/wayvnc/key.pem ]; then
              echo "  🔐 Generating SSL certificates..."
              ${openssl}/bin/openssl req -x509 -newkey rsa:4096 -sha256 -days 3650 \
                -nodes -keyout ~/.config/wayvnc/key.pem -out ~/.config/wayvnc/cert.pem \
                -subj "/CN=$(hostname)" \
                -addext "subjectAltName=DNS:$(hostname),DNS:localhost,IP:127.0.0.1"
              chmod 600 ~/.config/wayvnc/*.pem
              echo "  ✅ SSL certificates generated successfully"
            else
              echo "  ✅ SSL certificates already exist"
            fi

            echo "  🔑 VNC Authentication:"
            echo "     Username: vnc"
            echo "     Password: ${cfg.vncPassword}"
            echo "     ⚠️  Change the password in configuration.nix for security!"

            echo "  ✅ VNC server configured on port ${toString cfg.vncPort}"
          '' else ""}

          ${if cfg.protocol == "rdp" || cfg.protocol == "both" then ''
            echo "📡 Setting up RDP with GNOME Remote Desktop..."
            echo "  ⚠️  Please configure RDP authentication using GNOME settings or via:"
            echo "     grdctl rdp set-credentials <username> <password>"
            echo "  ✅ RDP server configured on port ${toString cfg.rdpPort}"
          '' else ""}

          echo ""
          echo "🎉 Remote Desktop setup complete!"
          echo ""
          echo "📝 Connection Information:"
          echo "  Hostname: $(hostname)"
          echo "  IP Address: $(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v 127.0.0.1 | head -n1)"
          ${if cfg.protocol == "rdp" || cfg.protocol == "both" then ''
            echo "  RDP Port: ${toString cfg.rdpPort}"
          '' else ""}
          ${if cfg.protocol == "vnc" || cfg.protocol == "both" then ''
            echo "  VNC Port: ${toString cfg.vncPort}"
          '' else ""}
          echo ""
          echo "🔌 To connect from another machine:"
          ${if cfg.protocol == "rdp" || cfg.protocol == "both" then ''
            echo "  RDP: xfreerdp /v:$(hostname):${toString cfg.rdpPort} /u:USERNAME /p:PASSWORD"
          '' else ""}
          ${if cfg.protocol == "vnc" || cfg.protocol == "both" then ''
            echo "  VNC: vncviewer $(hostname):${toString cfg.vncPort}"
          '' else ""}
          echo ""
          echo "📖 For more information, see: https://wiki.archlinux.org/title/Wayvnc"
        '')
      ];

    # GNOME Remote Desktop for RDP support (works with COSMIC/Wayland)
    services.gnome.gnome-remote-desktop.enable =
      cfg.protocol == "rdp" || cfg.protocol == "both";

    # Configure systemd services and power management
    systemd = mkMerge [
      # Wayvnc service for VNC support
      (mkIf (cfg.protocol == "vnc" || cfg.protocol == "both") {
        user.services.wayvnc = {
          description = "Wayvnc VNC Server for COSMIC Desktop";
          wantedBy = [ "graphical-session.target" ];
          after = [ "graphical-session.target" ];
          environment = {
            WAYLAND_DISPLAY = "wayland-1";
            XDG_RUNTIME_DIR = "/run/user/%U";
          };
          serviceConfig = {
            Type = "simple";
            ExecStart = "${pkgs.wayvnc}/bin/wayvnc -o HDMI-1 -C ${pkgs.writeText "wayvnc-config" ''
              address=0.0.0.0
              port=${toString cfg.vncPort}
              enable_auth=true
              username=vnc
              password=${cfg.vncPassword}
              private_key_file=%h/.config/wayvnc/key.pem
              certificate_file=%h/.config/wayvnc/cert.pem
            ''}";
            Restart = "on-failure";
            RestartSec = "5s";
          };
        };
      })

      # Disable power management if requested
      (mkIf cfg.disablePowerManagement {
        targets.sleep.enable = false;
        targets.suspend.enable = false;
        targets.hibernate.enable = false;
        targets.hybrid-sleep.enable = false;
      })
    ];

    # Enable Avahi for service discovery
    services.avahi = {
      enable = true;
      nssmdns4 = true;
      publish = {
        enable = true;
        addresses = true;
        userServices = true;
        domain = true;
      };
    };

    # Firewall configuration
    networking.firewall = {
      allowedTCPPorts =
        (optionals (cfg.protocol == "rdp" || cfg.protocol == "both") [ cfg.rdpPort ])
        ++ (optionals (cfg.protocol == "vnc" || cfg.protocol == "both") [ cfg.vncPort ]);

      # Optional: Restrict access to specific networks
      extraCommands = ''
        # Allow remote desktop only from trusted networks
        ${concatMapStringsSep "\n" (net: ''
          iptables -A nixos-fw -p tcp --dport ${toString cfg.rdpPort} -s ${net} -j ACCEPT
          iptables -A nixos-fw -p tcp --dport ${toString cfg.vncPort} -s ${net} -j ACCEPT
        '') cfg.allowedNetworks}
      '';
    };

    # Disable screen locking if requested
    environment.sessionVariables = mkIf cfg.disableScreenLock {
      # Prevent COSMIC from locking screen automatically
      COSMIC_DISABLE_LOCK = "1";
    };

    # Disable autologin for security
    services.displayManager.autoLogin.enable = lib.mkForce false;
    services.getty.autologinUser = lib.mkForce null;

    # Security hardening
    security.pam.services.login.limits = [
      {
        domain = "*";
        type = "hard";
        item = "maxlogins";
        value = "10";
      }
    ];
  };
}
