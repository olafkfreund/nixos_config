# Server Host-Specific Packages
# Packages specifically for server hosts (headless)
# Compliant with NIXOS-ANTI-PATTERNS.md
{ pkgs, ... }: {
  # Server-specific packages (headless-compatible only)
  environment.systemPackages = with pkgs; [
    # Server monitoring and administration
    fail2ban
    logrotate
    rsync

    # Network services
    nginx

    # Media server essentials (for P510)
    mediainfo
    ffmpeg

    # System performance tools
    iperf3
    bandwhich

    # Backup and maintenance
    rclone
    duplicity

    # Headless text editors
    vim
    nano

    # Server-specific monitoring
    smartmontools
    hdparm
  ];
}
