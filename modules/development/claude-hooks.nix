{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.features.claude-hooks;

  # Create the hook scripts
  needsPermissionsScript = pkgs.writeShellScript "needs-permissions.sh" ''
    #!/usr/bin/env bash

    # Send notification when Claude needs permissions
    if [ -n "$TMUX" ]; then
      tmux_session=$(${pkgs.tmux}/bin/tmux display-message -p '#S')
      ${pkgs.libnotify}/bin/notify-send "Claude" "Needs permissions in session: $tmux_session" -t 3000
    else
      ${pkgs.libnotify}/bin/notify-send "Claude" "Needs permissions" -t 3000
    fi
  '';

  notifyReadyScript = pkgs.writeShellScript "notify-ready.sh" ''
    #!/usr/bin/env bash

    # Send notification when Claude is done processing
    if [ -n "$TMUX" ]; then
      tmux_session=$(${pkgs.tmux}/bin/tmux display-message -p '#S')
      ${pkgs.libnotify}/bin/notify-send "Claude" "Waiting in session: $tmux_session" -t 3000
    else
      ${pkgs.libnotify}/bin/notify-send "Claude" "Waiting for input." -t 3000
    fi
  '';

  # Claude hooks configuration
  claudeHooksConfig = {
    hooks = mkMerge [
      (mkIf cfg.enablePermissionNotifications {
        PermissionRequest = [{
          matcher = "*";
          hooks = [{
            type = "command";
            command = toString needsPermissionsScript;
          }];
        }];
      })
      (mkIf cfg.enableReadyNotifications {
        Stop = [{
          hooks = [{
            type = "command";
            command = toString notifyReadyScript;
          }];
        }];
      })
    ];
  };
in
{
  options.features.claude-hooks = {
    enable = mkEnableOption "Claude Code hooks for desktop notifications";

    enablePermissionNotifications = mkOption {
      type = types.bool;
      default = true;
      description = "Enable notifications when Claude needs permissions";
    };

    enableReadyNotifications = mkOption {
      type = types.bool;
      default = true;
      description = "Enable notifications when Claude is ready for input";
    };
  };

  config = mkIf cfg.enable {
    # Ensure notification dependencies are available system-wide
    environment.systemPackages = with pkgs; [
      libnotify # For notify-send command
      tmux # For session detection
    ];

    # Configure Home Manager for all users
    home-manager.sharedModules = [{
      # Configure Claude settings with hooks
      xdg.configFile."claude/settings.json" = mkIf (cfg.enablePermissionNotifications || cfg.enableReadyNotifications) {
        text = builtins.toJSON claudeHooksConfig;
      };

      # Ensure tmux is available for session detection
      programs.tmux.enable = mkDefault true;
    }];
  };
}
