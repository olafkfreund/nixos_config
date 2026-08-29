{ config, lib, pkgs, ... }:

let
  inherit (lib) mkOption mkIf mkEnableOption mkDefault types;
  cfg = config.features.claude-hooks;

  # Hook script bodies. Kept as plain strings: building them with
  # writeShellScript only to read them back with builtins.readFile is
  # import-from-derivation, which stalls evaluation on a build.
  needsPermissionsText = ''
    #!/usr/bin/env bash

    # Send notification when Claude needs permissions
    if [ -n "$TMUX" ]; then
      tmux_session=$(${pkgs.tmux}/bin/tmux display-message -p '#S')
      ${pkgs.libnotify}/bin/notify-send "Claude" "Needs permissions in session: $tmux_session" -t 3000
    else
      ${pkgs.libnotify}/bin/notify-send "Claude" "Needs permissions" -t 3000
    fi
  '';

  notifyReadyText = ''
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
        (pkgs.writeScriptBin "claude-notify-permissions" needsPermissionsText)
        (pkgs.writeScriptBin "claude-notify-ready" notifyReadyText)
      ];
    }];
  };
}
