# Common dependency sets for reducing package duplication
{ pkgs }: {
  # Core monitoring tools used by all exporters
  monitoringTools = with pkgs; [
    curl # HTTP API requests
    jq # JSON processing
    bc # Mathematical calculations
    python3 # Script execution
  ];

  # Extended monitoring tools with network utilities
  extendedMonitoringTools = with pkgs; [
    curl
    jq
    bc
    python3
    netcat-gnu # Network connectivity testing
    gawk # Text processing
    coreutils # Basic utilities
    gnugrep # Text searching
    gnused # Text manipulation
  ];

  # Network analysis tools
  networkTools = with pkgs; [
    nettools # netstat, etc.
    iproute2 # ss, ip commands
    lsof # List open files
    procps # Process utilities
  ];

  # Basic development tools for all environments
  basicDevTools = with pkgs; [
    vim # Text editor
    git # Version control
    curl # HTTP client
    wget # File downloader
  ];

  # Container/K8s development tools
  containerDevTools = with pkgs; [
    kubectl
    k3s
    k9s
    kubernetes-helm
  ];

  # Extended development environment tools
  extendedDevTools = with pkgs; [
    vim
    git
    curl
    wget
    tmux # Terminal multiplexer
    htop # Process monitor
    iftop # Network monitor
    tree # Directory listing
  ];

  # Script processing dependencies
  scriptTools = with pkgs; [
    bc # Mathematical calculations
    jq # JSON processing
    gawk # Text processing
    gnugrep # Text searching
    gnused # Text manipulation
  ];

  # System administration script tools
  systemScriptTools = with pkgs; [
    bc
    smartmontools # Hardware monitoring
    yad # GUI dialogs
    procps # Process utilities
  ];
}
