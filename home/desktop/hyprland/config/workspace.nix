# Enhanced Workspace Configuration
# Smart multi-monitor workspace distribution with host-specific variables
{ lib
, host ? "default"
, ...
}:
with lib; let
  # Import host-specific variables if available
  hostVars =
    if builtins.pathExists ../../../../hosts/${host}/variables.nix
    then import ../../../../hosts/${host}/variables.nix
    else { };

  # Workspace configuration
  cfg = {
    # Multi-monitor setup
    multiMonitor = {
      enable = hostVars.monitors or [ ] != [ ];
      primaryMonitor = hostVars.primaryMonitor or "HDMI-A-1";
      secondaryMonitor = hostVars.secondaryMonitor or "eDP-1";

      # Workspace distribution
      primary = {
        workspaces = range 1 10;
        defaultWorkspace = 1;
      };

      secondary = {
        workspaces = range 11 19;
        defaultWorkspace = 11;
      };
    };

    # Special workspaces (scratchpads)
    special = {
      enable = true;
      workspaces = [
        "chrome"
        "firefox"
        "slack"
        "discord"
        "teams"
        "spotify"
        "mail"
        "tmux"
        "magic"
      ];
    };
  };

  # Generate workspace rules
  generateWorkspaceRules =
    let
      # Multi-monitor workspace distribution
      multiMonitorRules = optionals cfg.multiMonitor.enable (
        let
          primary = cfg.multiMonitor.primaryMonitor;
          secondary = cfg.multiMonitor.secondaryMonitor;
          primaryWorkspaces = cfg.multiMonitor.primary.workspaces;
          secondaryWorkspaces = cfg.multiMonitor.secondary.workspaces;
          defaultPrimary = cfg.multiMonitor.primary.defaultWorkspace;
          defaultSecondary = cfg.multiMonitor.secondary.defaultWorkspace;
        in
        (map (ws: "workspace = ${toString ws},monitor:${primary}${optionalString (ws == defaultPrimary) ",default:true"}") primaryWorkspaces)
        ++ (map (ws: "workspace = ${toString ws},monitor:${secondary}${optionalString (ws == defaultSecondary) ",default:true"}") secondaryWorkspaces)
      );

      # Single monitor fallback
      singleMonitorRules = optionals (!cfg.multiMonitor.enable) [
        "workspace = 1,default:true"
        "workspace = 2"
        "workspace = 3"
        "workspace = 4"
        "workspace = 5"
        "workspace = 6"
        "workspace = 7"
        "workspace = 8"
        "workspace = 9"
        "workspace = 10"
      ];

      # Special workspace configuration
      specialRules = optionals cfg.special.enable [
        "# Special workspaces for organized application management"
      ];
    in
    multiMonitorRules ++ singleMonitorRules ++ specialRules;
in
{
  wayland.windowManager.hyprland.extraConfig = concatStringsSep "\n" (
    [ "# Enhanced Workspace Rules with Smart Multi-Monitor Support" ]
    ++ generateWorkspaceRules
  );
}
