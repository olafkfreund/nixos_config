{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    adwaita-qt # For sddm to function properly
    bibata-cursors
    nix-prefetch-scripts
    polkit
    kdePackages.polkit-kde-agent-1
    qt5.qtgraphicaleffects

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
    alejandra # Nix formatter
    nixpkgs-fmt # Nix formatter (used by `just validate` and CI)
    deadnix # Dead-code detection
    statix # Nix anti-pattern linter
    devbox # faster nix-shells
    shellify # faster nix-shells
    github-desktop
    v4l-utils
    sops
  ];
}
