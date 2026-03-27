{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    adwaita-qt # For sddm to function properly
    bibata-cursors
    nix-prefetch-scripts
    polkit
    kdePackages.polkit-kde-agent-1
    libsForQt5.qt5.qtgraphicaleffects

    # Development tools (core tools like git, curl, jq are in nixos/packages/core.nix)
    openssl
    gcc
    gdb
    go
    gnumake
    ispell
    aspell
    sqlite
    z3
    nil # Nix lsp
    devbox # faster nix-shells
    shellify # faster nix-shells
    github-desktop
    v4l-utils
    sops
  ];
}
