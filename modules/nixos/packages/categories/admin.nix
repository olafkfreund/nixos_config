# Administrative Packages
# System administration and monitoring tools
# Compliant with NIXOS-ANTI-PATTERNS.md
{ config, lib, pkgs, ... }:
let
  cfg = config.packages.admin;
  # Import existing package sets
  packageSets = import ../../packages/sets.nix { inherit pkgs lib; };
in
{
  options.packages.admin = {
    enable = lib.mkEnableOption "Administrative packages";

    monitoring = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable monitoring tools (headless-compatible)";
    };

    network = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable network analysis tools (headless-compatible)";
    };

    security = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable security tools";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      # Core admin tools (headless-compatible)
      systemctl-tui
      journalctl
      htop
      iotop
    ]
    # Monitoring tools (headless-compatible)
    ++ lib.optionals cfg.monitoring packageSets.monitoring

    # Network tools (headless-compatible)
    ++ lib.optionals cfg.network packageSets.network

    # Security tools (mix of headless and GUI)
    ++ lib.optionals cfg.security (
      # Headless security tools
      [ gnupg pass ]
        # GUI security tools (only if desktop enabled)
        ++ lib.optionals (config.packages.desktop.enable or false) [
        pinentry-gtk2
        _1password-gui
        yubikey-manager-qt
      ]
        # CLI security tools
        ++ [ _1password yubikey-manager ]
    );
  };
}
