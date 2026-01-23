{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.features.claude-hooks;

  # Create the hook scripts for desktop notifications
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
    # Note: PARR protocol hooks are configured in home/development/claude-code-lsp.nix
    # which manages the ~/.claude/settings.json file directly
    home-manager.sharedModules = [{
      # Ensure tmux is available for session detection
      programs.tmux.enable = mkDefault true;

      # Make notification scripts available in the user environment
      home.packages = mkIf (cfg.enablePermissionNotifications || cfg.enableReadyNotifications) [
        (pkgs.writeScriptBin "claude-notify-permissions" (builtins.readFile needsPermissionsScript))
        (pkgs.writeScriptBin "claude-notify-ready" (builtins.readFile notifyReadyScript))
      ];
    }];
  };
}
