{ config
, lib
, pkgs
, inputs
, ...
}:
with lib; let
  cfg = config.features.desktop.cosmic-applet-package-updater;
in
{
  options.features.desktop.cosmic-applet-package-updater = {
    enable = mkEnableOption "COSMIC Package Updater Applet";

    autoCheck = mkOption {
      type = types.bool;
      default = true;
      description = "Automatically check for package updates at configured intervals";
    };

    checkIntervalMinutes = mkOption {
      type = types.int;
      default = 60;
      description = "Interval in minutes between package update checks";
    };

    nixosMode = mkOption {
      type = types.enum [ "flakes" "channels" "auto" ];
      default = "auto";
      description = ''
        NixOS update mode to use:
        - flakes: Use nix flake commands
        - channels: Use nixos-rebuild commands
        - auto: Auto-detect based on system configuration
      '';
    };

    configPath = mkOption {
      type = types.str;
      default = "/etc/nixos";
      description = "Path to NixOS configuration directory";
    };

    enablePasswordlessChecks = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Enable passwordless update checks for channels mode by adding sudoers rule.
        Only enables dry-run checks, actual updates still require password.
      '';
    };
  };

  config = mkMerge [
    # Main configuration when enabled
    (mkIf cfg.enable {
      # Install the COSMIC package updater applet
      environment.systemPackages = [
        inputs.cosmic-package-updater.packages.${pkgs.system}.default
      ];

      # XDG desktop database needs to be updated for applet discovery
      # This is handled automatically by NixOS
    })

    # Passwordless checks configuration (optional)
    (mkIf (cfg.enable && cfg.enablePasswordlessChecks) {
      # Add sudoers rule for passwordless dry-run checks
      security.sudo.extraRules = [
        {
          users = [ "%wheel" ];
          commands = [
            {
              command = "/run/current-system/sw/bin/nixos-rebuild dry-activate*";
              options = [ "NOPASSWD" ];
            }
          ];
        }
      ];
    })
  ];
}
