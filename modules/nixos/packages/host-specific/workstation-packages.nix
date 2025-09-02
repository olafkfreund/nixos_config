# Workstation Host-Specific Packages
# Packages specifically for workstation hosts
# Compliant with NIXOS-ANTI-PATTERNS.md
{ pkgs, ... }: {
  # Workstation-specific packages (mix of headless and GUI)
  environment.systemPackages = with pkgs; [
    # Development workstation tools
    docker-compose
    kubectl
    terraform

    # AI/ML development (for P620)
    python3Packages.torch
    python3Packages.transformers

    # Hardware-specific tools
    via
    wally-cli

    # Performance analysis
    perf-tools
    flamegraph

    # Advanced development
    gdb
    valgrind
    strace

    # Graphics and media development
    blender

    # Hardware monitoring
    gpu-viewer

    # Virtualization management
    virt-manager
  ];
}
