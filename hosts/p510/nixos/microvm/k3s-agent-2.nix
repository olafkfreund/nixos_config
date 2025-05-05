{
  config,
  lib,
  pkgs,
  ...
}: let
  username = "olafkfreund";
  hostname = "k3sagent2";
  masterIP = "192.168.1.202"; # Updated to match master IP
  k3sToken = "7j2hK6sVjkzN5sE8sF+pQyXlJd3w8bX0y5ZvX7K9KAo=";
  mac = "02:00:00:00:00:03"; # Unique MAC address for this agent
  ip = "192.168.1.204/24"; # Unique IP for this agent
in {
  # Enhanced microvm configuration
  microvm = {
    enable = true;
    hypervisor = "qemu";

    # Resource allocation - optimized for k3s agent
    mem = 4096; # 4GB RAM
    vcpu = 2; # 2 CPUs

    # CPU pinning for better performance
    qemuParams = [
      "-cpu host" # Use host CPU features for better performance
      "-smp 2,sockets=1,cores=2,threads=1" # Explicit CPU topology
    ];

    # Network interface configuration - using tap interface like other nodes
    interfaces = [
      {
        type = "tap";
        id = hostname;
        mac = mac;
      }
    ];

    # Shared storage configuration
    shares = [
      {
        tag = "ro-store";
        source = "/nix/store";
        mountPoint = "/nix/.ro-store";
      }
    ];

    # Persistent storage with proper volumes for k3s
    volumes = [
      {
        mountPoint = "/var";
        image = "var-agent2.img";
        size = 2048;
      }
      {
        mountPoint = "/var/lib/rancher/k3s";
        image = "k3s-agent2-data.img";
        size = 5120; # 5GB dedicated volume for k3s agent data
      }
    ];

    # Auto-start configuration
    autostart = true;

    # Socket activation for better integration with host system
    socket = true;
  };

  # Basic system configuration
  boot.isContainer = true;
  system.stateVersion = "24.11";

  # Set hostname explicitly
  networking.hostName = hostname;

  # Enhanced K3s configuration
  services.k3s = {
    enable = true;
    role = "agent";
    serverAddr = "https://${masterIP}:6443";
    token = k3sToken;
    extraFlags = toString [
      "--node-ip=${lib.head (lib.splitString "/" ip)}" # Extract IP without CIDR
      "--kubelet-arg=eviction-hard=memory.available<100Mi,nodefs.available<5%"
      "--kubelet-arg=eviction-minimum-reclaim=memory.available=100Mi,nodefs.available=1Gi"
    ];
  };

  # Networking optimization with static IP
  systemd.network = {
    enable = true;
    networks."20-lan" = {
      matchConfig.Type = "ether";
      networkConfig = {
        Address = [ip];
        Gateway = "192.168.1.254";
        DNS = ["8.8.8.8" "8.8.4.4"];
        IPv6AcceptRA = false;
        DHCP = "no";
      };
      # Increase MTU for better network performance
      linkConfig = {
        MTUBytes = "9000"; # Jumbo frames - match master configuration
      };
    };
  };

  # Disable old network configuration
  # networking.useDHCP = false;
  # networking.interfaces.eth0.useDHCP = true;

  # Disable firewall for k3s networking
  networking.firewall.enable = false;

  # Nix configuration
  nix = {
    enable = true;
    settings = {
      extra-experimental-features = ["nix-command" "flakes"];
      trusted-users = ["root" username];
      auto-optimise-store = true; # Optimize nix store
    };
    # Garbage collection
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };
  };

  # Security configuration
  security.sudo = {
    enable = true;
    wheelNeedsPassword = false;
  };

  # Auto-login
  services.getty.autologinUser = username;

  # SSH configuration - enhanced security
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "yes";
      PasswordAuthentication = false; # Enforce key-based auth
      KbdInteractiveAuthentication = false;
    };
  };

  # User configuration
  users.users.${username} = {
    isNormalUser = true;
    extraGroups = ["wheel" "docker" "kvm"]; # Added relevant groups
    initialPassword = "changeme";
    openssh.authorizedKeys.keys = [
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCMqMzUgRe2K350QBbQXbJFxVomsQbiIEw/ePUzjbyALklt5gMyo/yxbCWaKV1zeL4baR/vS5WOp9jytxceGFDaoJ7/O8yL4F2jj96Q5BKQOAz3NW/+Hmj/EemTOvVJWB1LQ+V7KgCbkxv6ZcUwL5a5+2QoujQNL5yVL3ZrIXv6LuKg8w8wykl57zDcJGgYsF+05oChswAmTFXI7hR5MdQgMGNM/eN78VZjSKJYGgeujoJg4BPQ6VE/qfIcJaPmuiiJBs0MDYIB8pKeSImXCDqYWEL6dZkSyro8HHHMAzFk1YP+pNIWVi8l3F+ajEFrEpTYKvdsZ4TiP/7CBaaI+0yVIq1mQ100AWeUiTn89iF8yqAgP8laLgMqZbM15Gm5UD7+g9/zsW0razyuclLogijvYRTMKt8vBa/rEfcx+qs8CuIrkXnD/KGfvoMDRgniWz8teaV1zfdDrkd6BhPVc5P3hI6gDY/xnSeijyyXL+XDE1ex6nfW5vNCwMiAWfDM+6k= olafkfreund@razer"
    ];
  };

  # Root user - blank password but SSH key auth only
  users.users.root.password = "";

  # System packages - enhanced with troubleshooting tools
  environment.systemPackages = with pkgs; [
    # Kubernetes tools
    kubectl
    k3s
    k9s
    kubernetes-helm

    # Core utilities
    vim
    curl
    wget
    git

    # Monitoring and debugging
    htop
    iftop
    tcpdump
    ethtool

    # System utilities
    tmux
    jq
    yq
  ];

  # Enable cgroups v2 for better container resource management
  boot.kernelParams = ["cgroup_enable=cpuset" "cgroup_memory=1" "cgroup_enable=memory"];

  # Sysctl tuning for Kubernetes
  boot.kernel.sysctl = {
    # Network optimization for k8s
    "net.ipv4.ip_forward" = 1;
    "net.bridge.bridge-nf-call-iptables" = 1;
    "net.bridge.bridge-nf-call-ip6tables" = 1;

    # Performance optimization
    "vm.swappiness" = 0; # Disable swapping for k8s
    "vm.overcommit_memory" = 1; # Allow overcommitting memory
    "kernel.panic" = 10; # Reboot after 10 seconds on kernel panic

    # File descriptor limits
    "fs.file-max" = 1048576; # Increase max file descriptors
  };
}
