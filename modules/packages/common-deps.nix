# Common dependency sets for reducing package duplication
# Restructured to eliminate overlapping packages and collisions
{ pkgs }: {
  # Core shared tools (used by multiple categories)
  coreTools = with pkgs; [
    curl # HTTP API requests
    jq # JSON processing
    bc # Mathematical calculations
    python3 # Script execution
    vim # Text editor
    git # Version control
  ];

  # Core monitoring tools used by all exporters
  monitoringTools = with pkgs; [
    # No overlap - core tools handled separately
  ];

  # Extended monitoring tools with network utilities (only additional tools)
  extendedMonitoringTools = with pkgs; [
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

  # Basic development tools (only additional tools beyond core)
  basicDevTools = with pkgs; [
    wget # File downloader
  ];

  # Container/K8s development tools
  containerDevTools = with pkgs; [
    kubectl
    k3s
    k9s
    kubernetes-helm
  ];

  # Extended development environment tools (only additional tools)
  extendedDevTools = with pkgs; [
    tmux # Terminal multiplexer
    htop # Process monitor
    iftop # Network monitor
    tree # Directory listing
  ];

  # Script processing dependencies (only additional tools beyond core)
  scriptTools = with pkgs; [
    gawk # Text processing
    gnugrep # Text searching
    gnused # Text manipulation
  ];

  # System administration script tools (only additional tools)
  systemScriptTools = with pkgs; [
    smartmontools # Hardware monitoring
    yad # GUI dialogs
    procps # Process utilities
  ];
}
