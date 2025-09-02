# Laptop Host-Specific Packages
# Packages specifically for laptop hosts
# Compliant with NIXOS-ANTI-PATTERNS.md
{ pkgs, ... }: {
  # Laptop-specific packages (optimized for mobility)
  environment.systemPackages = with pkgs; [
    # Power management tools
    powertop
    acpi
    tlp

    # Wireless and connectivity
    bluez-tools
    blueman

    # Mobile development
    android-tools
    scrcpy

    # Battery optimization
    auto-cpufreq

    # Screen management
    brightnessctl
    xrandr

    # Network management (mobile)
    networkmanager-openvpn
    networkmanager-vpnc

    # Lightweight productivity (mobile-optimized)
    zellij # Better than tmux for mobility
    ranger # File manager

    # Laptop hardware tools
    lshw
    dmidecode

    # Mobile security
    usbguard
  ];
}
