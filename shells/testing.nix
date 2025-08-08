# Testing Environment Shell
{ pkgs, ... }: 

pkgs.mkShell {
  name = "nixos-testing-environment";
  
  packages = with pkgs; [
    # VM and virtualization testing
    qemu_kvm
    cloud-utils
    virt-manager
    
    # Network testing and analysis
    netcat-gnu
    curl
    wget
    nmap
    iperf3
    tcpdump
    
    # System analysis and monitoring
    htop
    btop
    iotop
    nethogs
    lsof
    strace
    
    # Testing frameworks and tools
    python3
    python3Packages.pytest
    python3Packages.testinfra
    python3Packages.pyyaml
    python3Packages.requests
    
    # NixOS specific testing
    nixos-rebuild
    nixos-enter
    nixos-install
    
    # Hardware testing
    smartmontools
    lshw
    hwinfo
    stress-ng
    
    # Benchmarking
    sysbench
    fio
  ];

  shellHook = ''
    echo "🧪 NixOS Testing Environment"
    echo ""
    echo "🖥️  VM Testing:"
    echo "  qemu-kvm            - KVM virtualization"
    echo "  virt-manager        - VM management GUI"
    echo ""
    echo "🌐 Network Testing:"
    echo "  nmap                - Network scanning"
    echo "  iperf3              - Bandwidth testing"
    echo "  tcpdump             - Packet capture"
    echo ""
    echo "📊 System Analysis:"
    echo "  htop/btop           - Process monitoring" 
    echo "  iotop               - I/O monitoring"
    echo "  lsof                - File/network usage"
    echo ""
    echo "🔧 Testing Tools:"
    echo "  pytest              - Python test framework"
    echo "  stress-ng           - System stress testing"
    echo "  sysbench            - System benchmarking"
    echo ""
  '';

  # Environment variables for testing
  PYTHONPATH = "./tests:$PYTHONPATH";
  NIX_CONFIG = "experimental-features = nix-command flakes";
}