{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    adwaita-qt # For sddm to function properly
    bibata-cursors
    nix-prefetch-scripts
    polkit
    kdePackages.polkit-kde-agent-1
    libsForQt5.qt5.qtgraphicaleffects

    wget
    git
    curl
    file
    lsof
    lshw
    openssl
    ripgrep
    tcpdump
    tree
    unzip
    which
    gcc
    gdb
    go
    gnumake
    ispell
    aspell
    jq
    sqlite
    z3
    # Development
    nil # Nix lsp
    devbox # faster nix-shells
    shellify # faster nix-shells
    github-desktop
    swayosd
    v4l-utils
    sops
  ];
}
