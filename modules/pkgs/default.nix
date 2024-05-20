{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
      adwaita-qt# For sddm to function properly
      bibata-cursors
      nix-prefetch-scripts
      polkit
      libsForQt5.polkit-kde-agent
      libsForQt5.qt5.qtgraphicaleffects
      # sddm-themes.sugar-dark
      # sddm-themes.astronaut

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
      hplip
    ];
  }