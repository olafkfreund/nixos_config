# Core System Packages - Tier 1
# Essential packages that ALL hosts need regardless of purpose
# Compliant with NIXOS-ANTI-PATTERNS.md
{ pkgs, ... }: {
  config = {
    # Always installed - no conditions needed
    # Following anti-pattern: NO mkIf condition true!
    environment.systemPackages = with pkgs; [
      # Essential system tools (headless-compatible)
      curl
      wget
      git
      vim
      nano
      htop
      btop
      iotop
      systemctl
      journalctl
      openssh
      unzip
      gzip
      tar
      zip
      coreutils-full
      findutils
      gnugrep
      gnused
      gawk
      which
      tree
      file

      # Network essentials (headless-compatible)
      iproute2
      inetutils
      ping
      traceroute
      netcat
      dig
      nslookup
      dnsutils

      # System monitoring (headless-compatible)
      lsof
      pciutils
      usbutils
      procps
      psmisc

      # Basic development tools (headless-compatible)
      jq
      bc
      python3
    ];
  };
}
