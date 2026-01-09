_: {
  imports = [
    ./mtr/mtr.nix
    ./print/default.nix
    ./flatpak/flatpak.nix
    ./xserver/xdg-portal.nix
    ./xserver/xdg.nix
    ./bluetooth/bluetooth.nix
    ./sound/sound.nix
    ./openssh/openssh.nix
    ./gnome/gnome-services.nix
    ./systemd/default.nix
    ./system/default.nix
    ./cron/cron.nix
    ./atuin/default.nix
    ./logind/default.nix
    ./ollama/default.nix
    ./sysprof/default.nix
    ./mandb/default.nix
    ./appimage/default.nix
    ./dns/secure-dns.nix
    # ./flaresolverr/default.nix  # Commented out - NixOS has built-in FlareSolverr module

    # Network stability modules (service merged into main module)
    ./network-stability.nix

    # AI/MCP services
    ./whatsapp-bridge.nix

    # CI/CD services
    ./gitlab-runner.nix

    # System management services
    ./nixos-update-checker/default.nix

    # Security services
    ./security/mdatp.nix

    # Microsoft Intune Company Portal (custom package with version control)
    ./intune-portal.nix

    # Citrix Workspace for remote access
    ./citrix-workspace.nix

    # MCP servers for Claude Desktop
    ./rescreenshot-mcp.nix
  ];
}
