{
  config,
  pkgs,
  lib,
  hostUsers,
  ...
}: let
  vars = import ./variables.nix;
in {
  imports = [
    ./nixos/hardware-configuration.nix
    ./nixos/power.nix
    ./nixos/boot.nix
    ./nixos/i18n.nix
    ../../modules/default.nix
    ../../modules/development/default.nix
    ../../modules/secrets/api-keys.nix
  ];

  # Set hostname from variables
  networking.hostName = vars.hostName;

  # Choose networking profile: "server" for server configuration
  networking.profile = "server";
  
  # Tailscale VPN Configuration - DEX5550 as exit node and subnet router
  networking.tailscale = {
    enable = true;
    authKeyFile = config.age.secrets.tailscale-auth-key.path;
    hostname = "dex5550-server";
    exitNode = true;  # Enable as exit node for external internet access
    subnet = "192.168.1.0/24";  # Advertise home network subnet
    acceptRoutes = true;
    acceptDns = false;  # Use local BIND9 DNS
    ssh = true;
    shields = false;  # Disable shields for server to allow incoming connections
    useRoutingFeatures = "server";  # Act as router for other nodes
    extraUpFlags = [
      "--operator=olafkfreund"
      "--accept-risk=lose-ssh"
      "--advertise-tags=tag:server,tag:exitnode"
    ];
  };

  # Configure AI providers directly - lightweight config for low-power system
  ai.providers = {
    enable = true;
    defaultProvider = "anthropic";
    enableFallback = true;
    
    # Enable only cloud providers (no local Ollama to save resources)
    openai.enable = true;
    anthropic.enable = true;
    gemini.enable = true;
    ollama.enable = false;  # Disabled on low-power system
  };
  
  # Enable AI-powered system analysis
  ai.analysis = {
    enable = true;
    aiProvider = "anthropic";
    enableFallback = true;
    
    features = {
      performanceAnalysis = true;
      resourceOptimization = true;
      configDriftDetection = true;
      predictiveMaintenance = true;
      logAnalysis = true;
      securityAnalysis = true;
    };
    
    # Analysis intervals
    intervals = {
      performanceAnalysis = "hourly";  # Every hour
      maintenanceAnalysis = "daily";   # Once daily
      configDriftCheck = "*:0/6";      # Every 6 hours
      logAnalysis = "*:0/4";           # Every 4 hours
    };
  };

  # Use nameservers from variables (commented out to avoid conflict)
  # networking.nameservers = vars.nameservers;

  # Use the new features system instead of multiple lib.mkForce calls
  features = {
    development = {
      enable = true;
      ansible = true;   # Useful for server automation
      cargo = true;
      github = true;
      go = true;
      java = false;
      lua = true;
      nix = true;
      shell = true;
      devshell = false;
      python = true;
      nodejs = true;
    };

    virtualization = {
      enable = true;
      docker = true;
      incus = false;    # Disabled due to nftables requirement
      podman = true;
      spice = false;    # No GUI needed
      libvirt = true;   # Keep for server VMs
      sunshine = false; # No remote desktop needed
    };

    cloud = {
      enable = false;
      aws = false;
      azure = false;
      google = false;
      k8s = false;
      terraform = false;
    };

    security = {
      enable = true;
      onepassword = true;
      gnupg = true;
    };

    networking = {
      enable = true;
    };

    ai = {
      enable = true;   # Enable AI tools but no local inference
      ollama = false;  # Keep disabled - too resource intensive for SFF
    };

    programs = {
      lazygit = true;      # CLI tool, useful for server
      thunderbird = false;
      obsidian = false;
      office = false;
      webcam = false;      # No camera needed on server
      print = false;
    };

    media = {
      droidcam = false;    # No media capture on server
    };
  };

  # Monitoring configuration - DEX5550 as monitoring server
  monitoring = {
    enable = true;
    mode = "server";  # Now the monitoring server for network
    serverHost = "dex5550";
    
    features = {
      prometheus = true;    # Prometheus server
      grafana = true;       # Grafana dashboards
      nodeExporter = true;  # Local node exporter
      nixosMetrics = true;  # NixOS-specific metrics
      alerting = true;      # Alertmanager
      logging = true;       # Loki log aggregation server
      # Note: GPU metrics features are enabled for dashboard provisioning only
      # The actual GPU exporter services run on hosts with GPUs (razer, p510, p620)
      gpuMetrics = true;    # Enable GPU dashboards for NVIDIA clients
      amdGpuMetrics = true; # Enable AMD GPU dashboards for AMD clients
    };
  };

  # Zabbix monitoring server configuration
  modules.monitoring.zabbix = {
    enable = true;
    mode = "server";
    serverHost = "dex5550";
    
    snmpDevices = [
      {
        name = "Deco-Main-Router";
        ip = "192.168.1.1";
        community = "public";
        template = "Template Net TP-LINK SNMP";
      }
      {
        name = "Deco-Bedroom";
        ip = "192.168.1.10";
        community = "public";
        template = "Template Net TP-LINK SNMP";
      }
      {
        name = "Deco-Office";
        ip = "192.168.1.11";
        community = "public";
        template = "Template Net TP-LINK SNMP";
      }
      # Add Google devices (you'll need to find their IPs and enable SNMP)
      {
        name = "Google-Home-Living";
        ip = "192.168.1.100";  # Replace with actual IP
        community = "public";
        template = "Template Net Network Generic Device SNMP";
      }
      {
        name = "Google-Nest-Hub";
        ip = "192.168.1.101";  # Replace with actual IP
        community = "public";
        template = "Template Net Network Generic Device SNMP";
      }
    ];
    
    grafanaIntegration = {
      enable = true;
    };
  };

  # Custom Grafana configuration - configured for sub-path with external proxy
  services.grafana = {
    settings = {
      server = {
        root_url = lib.mkForce "https://home.freundcloud.com/grafana/";
        serve_from_sub_path = lib.mkForce true;
        domain = lib.mkForce "home.freundcloud.com";
        http_port = lib.mkForce 3001;
        protocol = lib.mkForce "http";
      };
    };
  };

  # Enable encrypted API keys
  secrets.apiKeys = {
    enable = true;
    enableEnvironmentVariables = true;
    enableUserEnvironment = true;
  };

  # Enable AI analysis Grafana dashboards
  ai.grafanaDashboards.enable = true;

  # Enable AI analysis Prometheus alerts
  ai.prometheusAlerts.enable = true;
  
  # Enable advanced alerting and notification system on monitoring server
  ai.alerting = {
    enable = true;
    
    # Email configuration
    enableEmail = true;
    smtpServer = "smtp.gmail.com";
    smtpPort = 587;
    fromEmail = "ai-alerts@freundcloud.com";
    alertRecipients = ["admin@freundcloud.com"];
    
    # Notification channels
    enableSlack = false;
    enableSms = false;
    enableDiscord = false;
    
    # Alert thresholds optimized for monitoring server
    alertThresholds = {
      diskUsage = 80;             # Lower threshold for monitoring server
      memoryUsage = 85;           # Important for Grafana/Prometheus
      cpuUsage = 85;              # Higher threshold for server workload
      aiResponseTime = 8000;      # AI response time in milliseconds
      sshFailedAttempts = 20;     # Higher threshold for public server
      serviceDowntime = 300;      # Service downtime in seconds
      loadTestFailures = 50;      # Load test failure rate %
    };
    
    # Escalation rules
    escalationRules = {
      level1 = {
        timeMinutes = 5;
        recipients = ["admin@freundcloud.com"];
        channels = ["email"];
      };
      level2 = {
        timeMinutes = 15;
        recipients = ["admin@freundcloud.com"];
        channels = ["email"];
      };
      level3 = {
        timeMinutes = 30;
        recipients = ["admin@freundcloud.com"];
        channels = ["email"];
      };
    };
    
    # Notification settings
    notificationTimeout = 30;
    notificationRetries = 3;
    
    # Maintenance mode
    maintenanceMode = false;
    
    # Alert levels configuration
    alertLevels = {
      critical = {
        email = true;
        slack = true;
        sms = true;
        discord = true;
      };
      warning = {
        email = true;
        slack = true;
        sms = false;
        discord = false;
      };
      info = {
        email = false;
        slack = false;
        sms = false;
        discord = false;
      };
    };
  };

  # Enable automated remediation for monitoring server
  ai.automatedRemediation = {
    enable = true;
    enableSelfHealing = true;   # Enable for monitoring server stability
    safeMode = true;           # Safe mode for critical monitoring infrastructure
    
    notifications = {
      enable = true;
      logFile = "/var/log/ai-analysis/remediation-dex5550.log";
    };
    
    actions = {
      diskCleanup = true;           # Keep monitoring server healthy
      memoryOptimization = true;    # Important for Grafana/Prometheus
      serviceRestart = true;        # Critical for monitoring services
      configurationReset = false;   # Keep disabled for safety
    };
  };

  # Enable advanced security auditing for monitoring server
  ai.securityAudit = {
    enable = true;
    auditLevel = "advanced";      # Advanced security audit for public-facing server
    autoHardening = false;        # Manual review required for monitoring server
    scheduleInterval = "daily";   # Daily security audits for public server
    reportPath = "/var/lib/ai-analysis/security-reports";
  };


  # BOOT PERFORMANCE: Prevent fstrim from blocking boot (saves 3+ minutes)
  services.fstrim-optimization = {
    enable = true;
    preventBootBlocking = true;
  };

  # Security services for management server
  services.openssh = {
    enable = true;
    settings = {
      # Harden SSH configuration
      PermitRootLogin = "no";
      PasswordAuthentication = false;
      PubkeyAuthentication = true;
      AuthenticationMethods = "publickey";
      MaxAuthTries = 3;
      ClientAliveInterval = 300;
      ClientAliveCountMax = 2;
      Compression = false;
      TCPKeepAlive = false;
      X11Forwarding = lib.mkForce false;
      AllowTcpForwarding = "no";
      AllowAgentForwarding = false;
      AllowStreamLocalForwarding = false;
      AuthorizedKeysFile = "/etc/ssh/authorized_keys.d/%u .ssh/authorized_keys .ssh/authorized_keys2";
      
      # Protocol and cipher hardening
      Protocol = 2;
      Ciphers = [
        "chacha20-poly1305@openssh.com"
        "aes256-gcm@openssh.com"
        "aes128-gcm@openssh.com"
        "aes256-ctr"
        "aes192-ctr"
        "aes128-ctr"
      ];
      KexAlgorithms = [
        "curve25519-sha256@libssh.org"
        "diffie-hellman-group16-sha512"
        "diffie-hellman-group18-sha512"
        "diffie-hellman-group14-sha256"
      ];
      Macs = [
        "hmac-sha2-256-etm@openssh.com"
        "hmac-sha2-512-etm@openssh.com"
        "hmac-sha2-256"
        "hmac-sha2-512"
      ];
    };
    
    # Only allow SSH from internal network initially
    listenAddresses = [
      { addr = "0.0.0.0"; port = 22; }
    ];
  };

  # System hardening and additional security services
  security.sudo = {
    wheelNeedsPassword = lib.mkForce true;
    # Allow passwordless sudo for olafkfreund user
    extraRules = [
      {
        users = [ "olafkfreund" ];
        commands = [
          {
            command = "ALL";
            options = [ "NOPASSWD" ];
          }
        ];
      }
      {
        users = [ vars.username ];
        commands = [
          {
            command = "/run/current-system/sw/bin/nixos-rebuild";
            options = [ "NOPASSWD" ];
          }
          {
            command = "/nix/store/*/bin/nixos-rebuild";
            options = [ "NOPASSWD" ];
          }
        ];
      }
    ];
  };
  security.protectKernelImage = true;
  security.apparmor.enable = true;
  security.auditd.enable = true;
  
  # Automatic security updates
  system.autoUpgrade = {
    enable = true;
    allowReboot = false;  # Manual reboot for servers
    dates = lib.mkForce "02:00";      # Run at 2 AM
    randomizedDelaySec = "45min";
    flake = lib.mkForce "github:olafkfreund/nixos_config";
  };

  # Server configuration - no GUI services needed
  services.xserver.enable = false;

  # Disable systemd-resolved to avoid conflicts with BIND9
  services.resolved.enable = lib.mkForce false;
  
  # BIND9 DNS Server - configured for internal network access
  services.bind = {
    enable = true;
    listenOn = [ "192.168.1.222" "127.0.0.1" ];
    listenOnIpv6 = [ "none" ];
    forwarders = [ "1.1.1.1" "8.8.8.8" ];
    
    # Simple configuration without ACLs
    extraConfig = "";
    
    # Configure caching
    cacheNetworks = [ "127.0.0.0/8" "192.168.1.0/24" ];
    
    zones."home.freundcloud.com" = {
      master = true;
      file = pkgs.writeText "home.freundcloud.com.zone" ''
        $TTL 86400
        @       IN      SOA     dex5550.home.freundcloud.com. admin.home.freundcloud.com. (
                        2025070801      ; Serial - updated for razer IP change
                        3600            ; Refresh
                        1800            ; Retry
                        604800          ; Expire
                        86400 )         ; Minimum TTL
        
        ; Name servers
        @       IN      NS      dex5550.home.freundcloud.com.
        
        ; A records for services and hosts
        @               IN      A       192.168.1.222
        dex5550         IN      A       192.168.1.222
        p620            IN      A       192.168.1.97
        razer           IN      A       192.168.1.188
        p510            IN      A       192.168.1.127
        grafana         IN      A       192.168.1.222
        prometheus      IN      A       192.168.1.222
        alertmanager    IN      A       192.168.1.222
        rss             IN      A       192.168.1.222
      '';
    };
  };
  
  # Use local DNS server
  networking.nameservers = [ "127.0.0.1" ];
  

  # Disable nftables to use iptables-based firewall
  networking.nftables.enable = lib.mkForce false;
  
  # Comprehensive firewall configuration for management server
  networking.firewall = {
    enable = lib.mkForce true;
    
    # Default deny policy - only explicitly allowed ports are open
    allowPing = true;
    
    # External access ports (will be secured by reverse proxy)
    allowedTCPPorts = [
      22   # SSH (will be rate limited)
      53   # DNS (TCP) - BIND9
      80   # HTTP (redirect to HTTPS)
      443  # HTTPS (reverse proxy)
    ];
    
    allowedUDPPorts = [
      53   # DNS (UDP) - BIND9
    ];
    
    # Internal network management ports (192.168.1.0/24 only)
    interfaces."eno1" = {
      allowedTCPPorts = [
        3001  # Grafana
        9090  # Prometheus
        9093  # Alertmanager
        9100  # Node Exporter
        9101  # NixOS Exporter
        9102  # Systemd Exporter
      ];
    };
  };

  # Fail2Ban configuration for additional SSH protection
  services.fail2ban = {
    enable = true;
    maxretry = 3;
    bantime = "1h";
    bantime-increment = {
      enable = true;
      multipliers = "1 2 4 8 16 32 64";
      maxtime = "168h"; # 1 week
      overalljails = true;
    };
    
    jails = {
      # SSH protection
      sshd = {
        settings = {
          enabled = true;
          filter = "sshd";
          maxretry = 3;
          findtime = "10m";
          bantime = "1h";
        };
      };
    };
  };

  # Server-specific configurations - no GUI hardware wrappers needed

  # Docker configuration
  modules.containers.docker = {
    enable = true;
    users = hostUsers; # Use all users for this host
    rootless = false;
  };

  # User-specific configuration from variables
  users.users.${vars.username} = {
    isNormalUser = true;
    description = vars.fullName;
    extraGroups = [
      "networkmanager"
      "libvirtd"
      "wheel"
      "docker"
      "podman"
      "lxd"
    ];
    shell = pkgs.zsh;
    packages = with pkgs; [
      vim
      htop
      tmux
      curl
      wget
      git
      # Security and monitoring tools
      iotop
      lsof
      nettools
      tcpdump
      nmap
      dig
      whois
      # Log analysis
      jq
      ripgrep
    ];
  };

  # Logging and monitoring for security
  services.logrotate = {
    enable = true;
    settings = {
      "/var/log/fail2ban.log" = {
        frequency = "daily";
        rotate = 7;
        compress = true;
        delaycompress = true;
        missingok = true;
        notifempty = true;
      };
      "/var/log/auth.log" = {
        frequency = "daily";
        rotate = 30;
        compress = true;
        delaycompress = true;
        missingok = true;
        notifempty = true;
      };
    };
  };

  # Kernel security hardening
  boot.kernel.sysctl = {
    # Network security
    "net.ipv4.ip_forward" = lib.mkForce 0;
    "net.ipv4.conf.all.send_redirects" = 0;
    "net.ipv4.conf.default.send_redirects" = 0;
    "net.ipv4.conf.all.accept_redirects" = 0;
    "net.ipv4.conf.default.accept_redirects" = 0;
    "net.ipv4.conf.all.accept_source_route" = 0;
    "net.ipv4.conf.default.accept_source_route" = 0;
    "net.ipv4.conf.all.log_martians" = 1;
    "net.ipv4.conf.default.log_martians" = 1;
    "net.ipv4.icmp_echo_ignore_broadcasts" = 1;
    "net.ipv4.icmp_ignore_bogus_error_responses" = 1;
    "net.ipv4.tcp_syncookies" = 1;
    "net.ipv4.tcp_rfc1337" = 1;
    
    # Memory protection
    "kernel.dmesg_restrict" = 1;
    "kernel.kptr_restrict" = 2;
    "kernel.yama.ptrace_scope" = 1;
    "vm.mmap_rnd_bits" = 32;
    "vm.mmap_rnd_compat_bits" = 16;
    
    # File system security
    "fs.protected_hardlinks" = 1;
    "fs.protected_symlinks" = 1;
    "fs.suid_dumpable" = 0;
  };

  # Server hardware configurations
  hardware.keyboard.zsa.enable = false; # No physical keyboard management needed
  services.ollama.acceleration =
    if vars.acceleration != ""
    then vars.acceleration
    else "cpu";
  hardware.nvidia-container-toolkit.enable = false;

  # Monitoring configuration handled by monitoring module




  # Traefik Reverse Proxy for external access
  services.traefik = {
    enable = true;
    
    # Static configuration
    staticConfigOptions = {
      # Entry points
      entryPoints = {
        web = {
          address = ":80";
          http.redirections.entrypoint = {
            to = "websecure";
            scheme = "https";
            permanent = true;
          };
        };
        websecure = {
          address = ":443";
        };
      };
      
      # Certificate resolvers
      certificatesResolvers = {
        letsencrypt = {
          acme = {
            tlsChallenge = {};
            email = "admin@freundcloud.com";
            storage = "/var/lib/traefik/acme.json";
            keyType = "EC256";
          };
        };
      };
      
      # API and dashboard
      api = {
        dashboard = true;
        insecure = false;  # Only accessible via HTTPS
      };
      
      # Metrics for monitoring
      metrics.prometheus.addEntryPointsLabels = true;
      
      # Logging
      log = {
        level = "INFO";
        filePath = "/var/log/traefik/traefik.log";
      };
      accessLog = {
        filePath = "/var/log/traefik/access.log";
      };
    };
    
    # Dynamic configuration via file
    dynamicConfigOptions = {
      http = {
        # Routers for internal services
        routers = {
          # Grafana router
          grafana = {
            rule = "Host(`home.freundcloud.com`) && PathPrefix(`/grafana`)";
            middlewares = [ "secure-headers" ];
            service = "grafana";
            tls.certResolver = "letsencrypt";
          };
          
          # Prometheus router
          prometheus = {
            rule = "Host(`home.freundcloud.com`) && PathPrefix(`/prometheus`)";
            middlewares = [ "prometheus-stripprefix" "secure-headers" ];
            service = "prometheus";
            tls.certResolver = "letsencrypt";
          };
          
          # Alertmanager router
          alertmanager = {
            rule = "Host(`home.freundcloud.com`) && PathPrefix(`/alertmanager`)";
            middlewares = [ "alertmanager-stripprefix" "secure-headers" ];
            service = "alertmanager";
            tls.certResolver = "letsencrypt";
          };
          
          # Zabbix router
          zabbix = {
            rule = "Host(`home.freundcloud.com`) && PathPrefix(`/zabbix`)";
            middlewares = [ "zabbix-stripprefix" "secure-headers" "zabbix-auth" ];
            service = "zabbix";
            tls.certResolver = "letsencrypt";
          };
          
          # Traefik dashboard router
          dashboard = {
            rule = "Host(`home.freundcloud.com`) && (PathPrefix(`/api`) || PathPrefix(`/dashboard`))";
            middlewares = [ "secure-headers" ];
            service = "api@internal";
            tls.certResolver = "letsencrypt";
          };
        };
        
        # Middlewares
        middlewares = {
          grafana-stripprefix = {
            stripPrefix.prefixes = [ "/grafana" ];
          };
          prometheus-stripprefix = {
            stripPrefix.prefixes = [ "/prometheus" ];
          };
          alertmanager-stripprefix = {
            stripPrefix.prefixes = [ "/alertmanager" ];
          };
          zabbix-stripprefix = {
            stripPrefix.prefixes = [ "/zabbix" ];
          };
          zabbix-auth = {
            basicAuth = {
              users = [ "admin:$2y$10$8K1p/a0dCN.UFUAASL/2Ounwz1KNB.ZYQH/A7RsKNLq/q/gKZvP0W" ];  # admin:zabbix123
            };
          };
          secure-headers = {
            headers = {
              customRequestHeaders = {
                "X-Forwarded-Proto" = "https";
              };
              customResponseHeaders = {
                "X-Frame-Options" = "DENY";
                "X-Content-Type-Options" = "nosniff";
                "Referrer-Policy" = "strict-origin-when-cross-origin";
                "Strict-Transport-Security" = "max-age=31536000; includeSubDomains";
              };
            };
          };
        };
        
        # Services
        services = {
          grafana = {
            loadBalancer.servers = [{
              url = "http://127.0.0.1:3001";
            }];
          };
          prometheus = {
            loadBalancer.servers = [{
              url = "http://127.0.0.1:9090";
            }];
          };
          alertmanager = {
            loadBalancer.servers = [{
              url = "http://127.0.0.1:9093";
            }];
          };
          zabbix = {
            loadBalancer.servers = [{
              url = "http://127.0.0.1:8081";
            }];
          };
        };
      };
    };
  };

  # Create log directories for Traefik
  systemd.tmpfiles.rules = [
    "d /var/log/traefik 0755 traefik traefik -"
    "d /var/lib/traefik 0700 traefik traefik -"
  ];

  # Additional security services
  environment.systemPackages = with pkgs; [
    # DNS tools
    bind          # DNS utilities (dig, nslookup, etc.)
    dnsutils      # Additional DNS utilities
    # Security analysis tools
    chkrootkit
    lynis
    # Network monitoring
    bandwhich
    nethogs
    iftop
    # Process monitoring
    pstree
    tree
  ];

  # Periodic security scanning
  systemd.services.security-scan = {
    description = "Periodic security scan";
    serviceConfig = {
      Type = "oneshot";
      User = "root";
      ExecStart = pkgs.writeShellScript "security-scan" ''
        echo "[$(date)] Starting security scan..."
        
        # Check for rootkits
        ${pkgs.chkrootkit}/bin/chkrootkit -q || echo "chkrootkit found issues"
        
        # Run system audit
        ${pkgs.lynis}/bin/lynis audit system --quick --quiet
        
        # Check open ports
        ${pkgs.nettools}/bin/netstat -tuln > /var/log/security-scan-ports.log
        
        echo "[$(date)] Security scan completed"
      '';
    };
  };

  systemd.timers.security-scan = {
    description = "Run security scan daily";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
      RandomizedDelaySec = "1h";
    };
  };

  # Performance Optimization Configuration (Phase 10.4)
  # Balanced monitoring server profile
  system.resourceManager = {
    enable = true;
    profile = "balanced";
    
    cpuManagement = {
      enable = true;
      dynamicGovernor = true;
      affinityOptimization = true;
      coreReservation = true;   # Reserve 2 cores for critical monitoring services
      reservedCores = 2;
    };
    
    memoryManagement = {
      enable = true;
      dynamicSwap = true;
      hugePagesOptimization = true;
      memoryCompression = true;  # Enable for monitoring server efficiency
      oomProtection = true;
    };
    
    ioManagement = {
      enable = true;
      dynamicScheduler = true;
      ioNiceOptimization = true;
      cacheOptimization = true;
    };
    
    networkManagement = {
      enable = true;
      trafficShaping = true;    # Enable for monitoring traffic prioritization
      connectionOptimization = true;
    };
  };
  
  # Network performance tuning for monitoring server
  networking.performanceTuning = {
    enable = true;
    profile = "balanced";
    
    tcpOptimization = {
      enable = true;
      congestionControl = "bbr";
      windowScaling = true;
      fastOpen = true;
      lowLatency = true;  # Important for monitoring responsiveness
    };
    
    bufferOptimization = {
      enable = true;
      receiveBuffer = 16777216;  # 16MB for monitoring data
      sendBuffer = 16777216;     # 16MB for monitoring data
      autotuning = true;
    };
    
    interHostOptimization = {
      enable = true;
      hosts = ["p620" "p510" "razer"];
      jumboFrames = false;
      routeOptimization = true;
    };
    
    dnsOptimization = {
      enable = true;
      caching = true;
      parallelQueries = true;
      customServers = ["127.0.0.1" "1.1.1.1"];  # Use local DNS first
    };
    
    monitoringOptimization = {
      enable = true;
      compression = true;
      batchingInterval = 15;  # Standard interval for monitoring server
      prioritization = true;
    };
  };
  
  # Storage performance optimization for monitoring server
  storage.performanceOptimization = {
    enable = true;
    profile = "reliability";  # Prioritize reliability for monitoring data
    
    ioSchedulerOptimization = {
      enable = true;
      dynamicScheduling = true;
      ssdOptimization = true;
      hddOptimization = false;  # DEX5550 uses SSD
    };
    
    filesystemOptimization = {
      enable = true;
      readaheadOptimization = true;
      cacheOptimization = true;
      compressionOptimization = false;
    };
    
    nvmeOptimization = {
      enable = false;  # DEX5550 uses SATA SSD
    };
    
    diskCacheOptimization = {
      enable = true;
      writeCache = true;
      readCache = true;
      barrierOptimization = false;  # Keep barriers for data integrity
    };
    
    tmpfsOptimization = {
      enable = true;
      tmpSize = "1G";      # Conservative for SFF system
      varTmpSize = "512M";
      devShmSize = "25%";
    };
  };
  
  # Performance analytics for monitoring server
  monitoring.performanceAnalytics = {
    enable = true;
    dataRetention = "60d";  # Longer retention for monitoring server
    analysisInterval = "5m";
    
    metricsCollection = {
      enable = true;
      systemMetrics = true;
      applicationMetrics = true;
      networkMetrics = true;
      storageMetrics = true;
      aiMetrics = true;
    };
    
    analytics = {
      enable = true;
      trendAnalysis = true;
      anomalyDetection = true;
      predictiveAnalysis = true;
      bottleneckDetection = true;
    };
    
    reporting = {
      enable = true;
      dailyReports = true;
      weeklyReports = true;
      alertThresholds = true;
    };
    
    dashboards = {
      enable = true;
      realTimeMetrics = true;
      historicalAnalysis = true;
      customMetrics = true;
    };
  };
  
  # AI-powered automated performance tuning for monitoring server
  ai.autoPerformanceTuner = {
    enable = true;
    aiProvider = "anthropic";
    enableFallback = true;
    tuningInterval = "hourly";  # Less frequent for stable monitoring server
    safeMode = true;  # Conservative tuning for critical monitoring infrastructure
    
    features = {
      adaptiveTuning = true;
      predictiveOptimization = true;
      workloadDetection = true;
      resourceBalancing = true;
      anomalyCorrection = true;
    };
    
    thresholds = {
      cpuUtilization = 80;     # Higher threshold for monitoring server
      memoryUtilization = 85;  # Important threshold for Grafana/Prometheus
      ioWait = 30;
      responseTime = 5000;     # Monitoring queries can be slower
    };
    
    notifications = {
      enable = true;
      logFile = "/var/log/ai-analysis/auto-tuner-dex5550.log";
    };
  };

  nixpkgs.config.permittedInsecurePackages = ["olm-3.2.16" "python3.12-youtube-dl-2021.12.17"];

  system.stateVersion = "25.11";
}
