# SSH Configuration Hardening Module
{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.security.sshHardening;
in
{
  options.security.sshHardening = {
    enable = mkEnableOption "Enable SSH security hardening";

    allowedUsers = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "List of users allowed SSH access";
    };

    allowPasswordAuthentication = mkOption {
      type = types.bool;
      default = false;
      description = "Allow password authentication (disabled by default for security)";
    };

    allowRootLogin = mkOption {
      type = types.bool;
      default = false;
      description = "Allow root login via SSH (disabled by default)";
    };

    maxAuthTries = mkOption {
      type = types.int;
      default = 3;
      description = "Maximum authentication attempts per connection";
    };

    clientAliveInterval = mkOption {
      type = types.int;
      default = 300;
      description = "Time (in seconds) the server will wait before sending a null packet to the client";
    };

    clientAliveCountMax = mkOption {
      type = types.int;
      default = 2;
      description = "Number of client alive messages sent without client response";
    };

    listenPort = mkOption {
      type = types.int;
      default = 22;
      description = "SSH listen port";
    };

    enableFail2Ban = mkOption {
      type = types.bool;
      default = true;
      description = "Enable fail2ban for SSH protection";
    };

    enableKeyOnlyAccess = mkOption {
      type = types.bool;
      default = true;
      description = "Enable key-only access (disables password authentication)";
    };

    enableStrictModes = mkOption {
      type = types.bool;
      default = true;
      description = "Enable strict file and directory permission checks";
    };

    trustedNetworks = mkOption {
      type = types.listOf types.str;
      default = [ "192.168.1.0/24" "10.0.0.0/8" "172.16.0.0/12" ];
      description = "List of trusted network CIDRs for SSH access";
    };
  };

  config = mkIf cfg.enable {
    # Consolidated services configuration
    services = {
      # SSH daemon configuration with security hardening
      openssh = {
        enable = true;
        ports = [ cfg.listenPort ];

        settings = {
          # Authentication
          PasswordAuthentication = cfg.allowPasswordAuthentication;
          PermitRootLogin = if cfg.allowRootLogin then "yes" else "no";
          PubkeyAuthentication = true;
          AuthenticationMethods = if cfg.enableKeyOnlyAccess then "publickey" else "publickey,password";
          MaxAuthTries = cfg.maxAuthTries;

          # Connection settings
          ClientAliveInterval = cfg.clientAliveInterval;
          ClientAliveCountMax = cfg.clientAliveCountMax;
          MaxSessions = 10;
          MaxStartups = "10:30:100";
          LoginGraceTime = 60;

          # Security settings
          Protocol = 2;
          StrictModes = cfg.enableStrictModes;
          IgnoreRhosts = true;
          HostbasedAuthentication = false;
          PermitEmptyPasswords = false;
          ChallengeResponseAuthentication = false;
          KerberosAuthentication = false;
          GSSAPIAuthentication = false;
          UsePAM = true;

          # Logging
          LogLevel = "VERBOSE";

          # Compression
          Compression = false;

          # Forwarding restrictions
          AllowTcpForwarding = "yes";
          AllowAgentForwarding = "yes";
          GatewayPorts = "no";
          X11Forwarding = mkForce false;

          # Modern cryptography
          KexAlgorithms = [
            "curve25519-sha256"
            "curve25519-sha256@libssh.org"
            "diffie-hellman-group16-sha512"
            "diffie-hellman-group18-sha512"
            "diffie-hellman-group-exchange-sha256"
          ];

          Ciphers = [
            "chacha20-poly1305@openssh.com"
            "aes256-gcm@openssh.com"
            "aes128-gcm@openssh.com"
            "aes256-ctr"
            "aes192-ctr"
            "aes128-ctr"
          ];

          Macs = [
            "hmac-sha2-256-etm@openssh.com"
            "hmac-sha2-512-etm@openssh.com"
            "hmac-sha2-256"
            "hmac-sha2-512"
          ];
        };

        # Only allow specific users if configured
        allowSFTP = false;
        extraConfig = ''
          # Additional security configurations
          ${optionalString (cfg.allowedUsers != []) "AllowUsers ${concatStringsSep " " cfg.allowedUsers}"}

          # Banner
          Banner /etc/ssh/banner

          # Subsystems
          Subsystem sftp internal-sftp

          # Match conditions for enhanced security
          Match Address ${concatStringsSep "," cfg.trustedNetworks}
              PasswordAuthentication ${if cfg.allowPasswordAuthentication then "yes" else "no"}
              MaxAuthTries ${toString cfg.maxAuthTries}

          Match Address *,!${concatStringsSep ",!" cfg.trustedNetworks}
              PasswordAuthentication no
              MaxAuthTries 1
              DenyUsers *
        '';
      };

      # Fail2ban configuration for SSH protection
      fail2ban = mkIf cfg.enableFail2Ban {
        enable = true;
        maxretry = cfg.maxAuthTries;
        bantime = "1h";

        jails = {
          ssh.settings = {
            enabled = true;
            filter = "sshd";
            maxretry = cfg.maxAuthTries;
            findtime = "10m";
            bantime = "1h";
          };
        };
      };

      # Enhanced logging for SSH events
      journald.extraConfig = ''
        # Increase journal size for SSH logging
        SystemMaxUse=1G
        RuntimeMaxUse=256M
      '';
    };

    # SSH banner warning
    environment.etc."ssh/banner".text = ''
      ================================================================================
      AUTHORIZED USE ONLY
      ================================================================================

      This computer system is for authorized users only. All activities on this
      system are logged and monitored. Unauthorized access is strictly prohibited
      and will be prosecuted to the full extent of the law.

      By accessing this system, you acknowledge that:
      - Your activities may be monitored and recorded
      - Unauthorized access is a criminal offense
      - You consent to monitoring for security purposes

      Disconnect immediately if you are not an authorized user.
      ================================================================================
    '';


    # Firewall configuration for SSH
    networking.firewall = {
      allowedTCPPorts = [ cfg.listenPort ];

      # Extra rules for SSH protection
      extraCommands = ''
        # Rate limiting for SSH connections
        iptables -I INPUT -p tcp --dport ${toString cfg.listenPort} -m conntrack --ctstate NEW -m recent --set --name SSH_LIMIT
        iptables -I INPUT -p tcp --dport ${toString cfg.listenPort} -m conntrack --ctstate NEW -m recent --update --seconds 60 --hitcount 4 --name SSH_LIMIT -j DROP

        # Allow established SSH connections
        iptables -A INPUT -p tcp --dport ${toString cfg.listenPort} -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

        # Log dropped SSH attempts
        iptables -A INPUT -p tcp --dport ${toString cfg.listenPort} -j LOG --log-prefix "SSH-DROP: " --log-level 4
      '';

      extraStopCommands = ''
        # Clean up SSH rules
        iptables -D INPUT -p tcp --dport ${toString cfg.listenPort} -m conntrack --ctstate NEW -m recent --set --name SSH_LIMIT 2>/dev/null || true
        iptables -D INPUT -p tcp --dport ${toString cfg.listenPort} -m conntrack --ctstate NEW -m recent --update --seconds 60 --hitcount 4 --name SSH_LIMIT -j DROP 2>/dev/null || true
      '';
    };

    # SSH client hardening
    programs.ssh = {
      extraConfig = ''
        # Client security configuration
        Host *
            # Use modern crypto
            KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org,diffie-hellman-group16-sha512,diffie-hellman-group18-sha512
            Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr
            MACs hmac-sha2-256-etm@openssh.com,hmac-sha2-512-etm@openssh.com,hmac-sha2-256,hmac-sha2-512

            # Security settings
            StrictHostKeyChecking ask
            VerifyHostKeyDNS yes
            ForwardAgent no
            ForwardX11 no
            ForwardX11Trusted no
            PermitLocalCommand no
            Tunnel no

            # Connection settings
            ServerAliveInterval 300
            ServerAliveCountMax 2
            TCPKeepAlive yes

            # Authentication
            PreferredAuthentications publickey,keyboard-interactive,password
            PubkeyAuthentication yes
            PasswordAuthentication ${if cfg.allowPasswordAuthentication then "yes" else "no"}
      '';
    };


    # Consolidated systemd configuration
    systemd = {
      # Journal logging configuration for SSH
      services = {
        ssh-journal-cleanup = {
          description = "SSH Journal Cleanup";
          serviceConfig = {
            Type = "oneshot";
            ExecStart = "${pkgs.systemd}/bin/journalctl --vacuum-time=30d --unit=sshd";
          };
        };

        # SSH monitoring and alerting
        ssh-monitor = {
          description = "SSH Connection Monitor";
          after = [ "network.target" "sshd.service" ];
          wants = [ "sshd.service" ];

          serviceConfig = {
            Type = "oneshot";
            User = "root";
            ExecStart = pkgs.writeShellScript "ssh-monitor" ''
              #!/bin/bash

              LOG_FILE="/var/log/ssh-monitor.log"
              ALERT_THRESHOLD=5
              TIME_WINDOW=300  # 5 minutes

              # Count failed login attempts in the last 5 minutes
              FAILED_ATTEMPTS=$(journalctl -u sshd --since="5 minutes ago" | \
                               grep "Failed password" | wc -l)

              # Count successful logins in the last 5 minutes
              SUCCESSFUL_LOGINS=$(journalctl -u sshd --since="5 minutes ago" | \
                                 grep -E "Accepted (publickey|password)" | wc -l)

              # Log current status
              echo "$(date): Failed attempts: $FAILED_ATTEMPTS, Successful logins: $SUCCESSFUL_LOGINS" >> "$LOG_FILE"

              # Alert on excessive failed attempts
              if [ "$FAILED_ATTEMPTS" -gt "$ALERT_THRESHOLD" ]; then
                logger -t ssh-monitor "ALERT: $FAILED_ATTEMPTS failed SSH login attempts in last 5 minutes"
                echo "$(date): ALERT - Excessive failed login attempts: $FAILED_ATTEMPTS" >> "$LOG_FILE"
              fi

              # Clean up old log entries (keep last 1000 lines)
              tail -1000 "$LOG_FILE" > "$LOG_FILE.tmp" && mv "$LOG_FILE.tmp" "$LOG_FILE"
            '';
          };
        };
      };

      timers = {
        ssh-journal-cleanup = {
          description = "SSH Journal Cleanup Timer";
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnCalendar = "weekly";
            Persistent = true;
          };
        };

        # Timer for SSH monitoring
        ssh-monitor = {
          description = "SSH Monitor Timer";
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnCalendar = "*:0/5"; # Every 5 minutes
            Persistent = true;
          };
        };
      };
    };

    # SSH key management script
    environment.systemPackages = with pkgs; [
      openssh
      fail2ban
      (writeShellScriptBin "ssh-security-check" ''
        #!/bin/bash

        echo "=== SSH Security Status ==="
        echo

        # SSH service status
        echo "SSH Service Status:"
        systemctl status sshd --no-pager -l
        echo

        # Active connections
        echo "Active SSH Connections:"
        ss -tnp | grep :${toString cfg.listenPort} || echo "No active SSH connections"
        echo

        # Recent failed attempts
        echo "Recent Failed Login Attempts (last 24h):"
        journalctl -u sshd --since="24 hours ago" | grep "Failed password" | tail -10 || echo "No recent failed attempts"
        echo

        # Recent successful logins
        echo "Recent Successful Logins (last 24h):"
        journalctl -u sshd --since="24 hours ago" | grep "Accepted" | tail -10 || echo "No recent successful logins"
        echo

        # Fail2ban status
        if command -v fail2ban-client &> /dev/null; then
          echo "Fail2ban Status:"
          fail2ban-client status ssh 2>/dev/null || echo "Fail2ban SSH jail not active"
          echo
        fi

        # SSH configuration validation
        echo "SSH Configuration Test:"
        sshd -t && echo "SSH configuration is valid" || echo "SSH configuration has errors"
        echo

        # Key information
        echo "SSH Host Keys:"
        for key in /etc/ssh/ssh_host_*_key.pub; do
          if [ -f "$key" ]; then
            echo "$(basename "$key"): $(ssh-keygen -lf "$key")"
          fi
        done
      '')

      (writeShellScriptBin "ssh-user-keys" ''
        #!/bin/bash

        if [ $# -eq 0 ]; then
          echo "Usage: $0 <username> [add|remove|list] [public_key_file]"
          exit 1
        fi

        USERNAME="$1"
        ACTION="''${2:-list}"
        KEY_FILE="$3"

        USER_HOME=$(getent passwd "$USERNAME" | cut -d: -f6)
        if [ -z "$USER_HOME" ]; then
          echo "Error: User $USERNAME not found"
          exit 1
        fi

        SSH_DIR="$USER_HOME/.ssh"
        AUTHORIZED_KEYS="$SSH_DIR/authorized_keys"

        case "$ACTION" in
          list)
            echo "SSH keys for user $USERNAME:"
            if [ -f "$AUTHORIZED_KEYS" ]; then
              cat "$AUTHORIZED_KEYS" | while read -r line; do
                if [ -n "$line" ] && [[ ! "$line" =~ ^# ]]; then
                  echo "  $(echo "$line" | ssh-keygen -lf -)"
                fi
              done
            else
              echo "  No authorized keys found"
            fi
            ;;
          add)
            if [ -z "$KEY_FILE" ]; then
              echo "Error: Public key file required for add operation"
              exit 1
            fi
            if [ ! -f "$KEY_FILE" ]; then
              echo "Error: Key file $KEY_FILE not found"
              exit 1
            fi

            # Create SSH directory if it doesn't exist
            mkdir -p "$SSH_DIR"
            chown "$USERNAME:$(id -gn "$USERNAME")" "$SSH_DIR"
            chmod 700 "$SSH_DIR"

            # Add key
            cat "$KEY_FILE" >> "$AUTHORIZED_KEYS"
            chown "$USERNAME:$(id -gn "$USERNAME")" "$AUTHORIZED_KEYS"
            chmod 600 "$AUTHORIZED_KEYS"

            echo "Added key from $KEY_FILE to $USERNAME's authorized keys"
            ;;
          remove)
            if [ -z "$KEY_FILE" ]; then
              echo "Error: Public key file required for remove operation"
              exit 1
            fi
            if [ ! -f "$AUTHORIZED_KEYS" ]; then
              echo "Error: No authorized keys file found for $USERNAME"
              exit 1
            fi

            # Remove matching key
            KEY_CONTENT=$(cat "$KEY_FILE")
            grep -v -F "$KEY_CONTENT" "$AUTHORIZED_KEYS" > "$AUTHORIZED_KEYS.tmp"
            mv "$AUTHORIZED_KEYS.tmp" "$AUTHORIZED_KEYS"

            echo "Removed key from $USERNAME's authorized keys"
            ;;
          *)
            echo "Error: Unknown action $ACTION"
            echo "Valid actions: list, add, remove"
            exit 1
            ;;
        esac
      '')
    ];

    # SSH security audit script
    systemd.services.ssh-security-audit = {
      description = "SSH Security Audit";

      serviceConfig = {
        Type = "oneshot";
        User = "root";
        ExecStart = pkgs.writeShellScript "ssh-security-audit" ''
          #!/bin/bash

          AUDIT_LOG="/var/log/ssh-security-audit.log"
          TIMESTAMP=$(date -Iseconds)

          echo "[$TIMESTAMP] Starting SSH security audit..." >> "$AUDIT_LOG"

          # Check SSH configuration
          if sshd -t 2>/dev/null; then
            echo "[$TIMESTAMP] SSH configuration: PASS" >> "$AUDIT_LOG"
          else
            echo "[$TIMESTAMP] SSH configuration: FAIL - Configuration errors detected" >> "$AUDIT_LOG"
          fi

          # Check for weak authentication methods
          if grep -q "PasswordAuthentication yes" /etc/ssh/sshd_config; then
            echo "[$TIMESTAMP] Password authentication: WARNING - Enabled" >> "$AUDIT_LOG"
          else
            echo "[$TIMESTAMP] Password authentication: PASS - Disabled" >> "$AUDIT_LOG"
          fi

          # Check for root login
          if grep -q "PermitRootLogin yes" /etc/ssh/sshd_config; then
            echo "[$TIMESTAMP] Root login: WARNING - Enabled" >> "$AUDIT_LOG"
          else
            echo "[$TIMESTAMP] Root login: PASS - Disabled" >> "$AUDIT_LOG"
          fi

          # Check host key permissions
          for key in /etc/ssh/ssh_host_*_key; do
            if [ -f "$key" ]; then
              PERMS=$(stat -c "%a" "$key")
              if [ "$PERMS" = "600" ]; then
                echo "[$TIMESTAMP] Host key $key permissions: PASS" >> "$AUDIT_LOG"
              else
                echo "[$TIMESTAMP] Host key $key permissions: FAIL - $PERMS (should be 600)" >> "$AUDIT_LOG"
              fi
            fi
          done

          # Check for recent security events
          FAILED_COUNT=$(journalctl -u sshd --since="24 hours ago" | grep -c "Failed password" || echo 0)
          echo "[$TIMESTAMP] Failed login attempts (24h): $FAILED_COUNT" >> "$AUDIT_LOG"

          # Check fail2ban status
          if command -v fail2ban-client &> /dev/null; then
            BANNED_IPS=$(fail2ban-client status ssh 2>/dev/null | grep "Banned IP list" | wc -w)
            echo "[$TIMESTAMP] Fail2ban banned IPs: $BANNED_IPS" >> "$AUDIT_LOG"
          fi

          echo "[$TIMESTAMP] SSH security audit completed" >> "$AUDIT_LOG"
        '';
      };
    };

    # Timer for SSH security audit
    systemd.timers.ssh-security-audit = {
      description = "SSH Security Audit Timer";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
        RandomizedDelaySec = "1h";
      };
    };
  };
}
