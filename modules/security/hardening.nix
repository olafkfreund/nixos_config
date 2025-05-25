{
  config,
  lib,
  ...
}: {
  options.modules.security.hardening = {
    enable = lib.mkEnableOption "security hardening";

    level = lib.mkOption {
      type = lib.types.enum ["basic" "standard" "strict"];
      default = "standard";
      description = "Security hardening level";
    };

    firewall = {
      strictMode = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable strict firewall mode";
      };

      allowedServices = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = ["ssh"];
        description = "Services to allow through firewall";
        example = ["ssh" "http" "https"];
      };
    };

    ssh = {
      hardenConfig = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Apply SSH hardening configuration";
      };

      allowedUsers = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Users allowed to SSH (empty = all wheel users)";
        example = ["admin" "user1"];
      };
    };

    auditd = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable audit daemon for security monitoring";
      };
    };
  };

  config = lib.mkIf config.modules.security.hardening.enable (lib.mkMerge [
    # Basic security (all levels)
    {
      # Disable unnecessary services
      services.avahi.enable = lib.mkForce false;
      services.printing.enable = lib.mkDefault false;

      # Secure kernel parameters
      boot.kernel.sysctl = {
        # Disable IP forwarding unless explicitly needed
        "net.ipv4.ip_forward" = lib.mkDefault 0;
        "net.ipv6.conf.all.forwarding" = lib.mkDefault 0;

        # Prevent IP spoofing
        "net.ipv4.conf.all.rp_filter" = 1;
        "net.ipv4.conf.default.rp_filter" = 1;

        # Disable ICMP redirects
        "net.ipv4.conf.all.accept_redirects" = 0;
        "net.ipv4.conf.default.accept_redirects" = 0;
        "net.ipv6.conf.all.accept_redirects" = 0;
        "net.ipv6.conf.default.accept_redirects" = 0;

        # Disable source routing
        "net.ipv4.conf.all.accept_source_route" = 0;
        "net.ipv4.conf.default.accept_source_route" = 0;
        "net.ipv6.conf.all.accept_source_route" = 0;
        "net.ipv6.conf.default.accept_source_route" = 0;

        # Log suspicious packets
        "net.ipv4.conf.all.log_martians" = 1;
        "net.ipv4.conf.default.log_martians" = 1;
      };

      # Firewall configuration
      networking.firewall = {
        enable = true;
        allowPing = lib.mkDefault false;
        logReversePathDrops = config.modules.security.hardening.firewall.strictMode;

        # Service-based port opening
        allowedTCPPorts = lib.flatten [
          (lib.optional (builtins.elem "ssh" config.modules.security.hardening.firewall.allowedServices) 22)
          (lib.optional (builtins.elem "http" config.modules.security.hardening.firewall.allowedServices) 80)
          (lib.optional (builtins.elem "https" config.modules.security.hardening.firewall.allowedServices) 443)
        ];
      };
    }

    # Standard security
    (lib.mkIf (config.modules.security.hardening.level
      == "standard"
      || config.modules.security.hardening.level == "strict") {
      # SSH hardening
      services.openssh = lib.mkIf config.modules.security.hardening.ssh.hardenConfig {
        enable = true;
        settings = {
          # Authentication
          PasswordAuthentication = false;
          PermitRootLogin = "no";
          PubkeyAuthentication = true;
          AuthenticationMethods = "publickey";

          # Protocol settings
          Protocol = 2;
          X11Forwarding = false;
          AllowAgentForwarding = false;
          AllowTcpForwarding = false;

          # Session limits
          MaxAuthTries = 3;
          MaxSessions = 2;
          ClientAliveInterval = 300;
          ClientAliveCountMax = 2;

          # User restrictions
          AllowUsers =
            lib.mkIf (config.modules.security.hardening.ssh.allowedUsers != [])
            config.modules.security.hardening.ssh.allowedUsers;
        };

        extraConfig = ''
          # Additional hardening
          Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr
          MACs hmac-sha2-256-etm@openssh.com,hmac-sha2-512-etm@openssh.com,hmac-sha2-256,hmac-sha2-512
          KexAlgorithms curve25519-sha256@libssh.org,diffie-hellman-group16-sha512,diffie-hellman-group18-sha512
        '';
      };

      # Fail2ban for intrusion prevention
      services.fail2ban = {
        enable = true;
        maxretry = 3;
        bantime = "1h";
        bantime-increment = {
          enable = true;
          maxtime = "168h"; # 1 week
          factor = "4";
        };

        jails = {
          sshd = {
            settings = {
              enabled = true;
              port = "ssh";
              filter = "sshd";
              logpath = "/var/log/auth.log";
              maxretry = 3;
              bantime = "3600";
            };
          };
        };
      };

      # Sudo security
      security.sudo = {
        enable = true;
        execWheelOnly = true;
        requireAuthentication = true;
        extraConfig = ''
          # Require password for sudo
          Defaults timestamp_timeout=5
          Defaults passwd_timeout=1
          Defaults passwd_tries=3

          # Log sudo commands
          Defaults logfile="/var/log/sudo.log"
        '';
      };
    })

    # Strict security
    (lib.mkIf (config.modules.security.hardening.level == "strict") {
      # Audit daemon
      security.auditd.enable = config.modules.security.hardening.auditd.enable;

      # Additional kernel hardening
      boot.kernel.sysctl = {
        # Kernel security
        "kernel.dmesg_restrict" = 1;
        "kernel.kptr_restrict" = 2;
        "kernel.yama.ptrace_scope" = 2;

        # Memory protection
        "kernel.exec-shield" = 1;
        "kernel.randomize_va_space" = 2;

        # Network security
        "net.ipv4.tcp_syncookies" = 1;
        "net.ipv4.tcp_rfc1337" = 1;
        "net.ipv4.icmp_echo_ignore_broadcasts" = 1;
        "net.ipv4.icmp_ignore_bogus_error_responses" = 1;
      };

      # Additional firewall rules for strict mode
      networking.firewall = {
        extraCommands = ''
          # Drop invalid packets
          iptables -A INPUT -m conntrack --ctstate INVALID -j DROP

          # Rate limit new connections
          iptables -A INPUT -p tcp --dport 22 -m conntrack --ctstate NEW -m limit --limit 5/min --limit-burst 5 -j ACCEPT

          # Log dropped packets (be careful with log volume)
          iptables -A INPUT -j LOG --log-prefix "DROPPED: " --log-level 4
        '';
      };

      # Mount options for security
      fileSystems = {
        "/tmp" = {
          device = "tmpfs";
          fsType = "tmpfs";
          options = ["nodev" "nosuid" "noexec" "size=2G"];
        };
      };

      # Process restrictions
      security.protectKernelImage = true;
    })
  ]);
}
