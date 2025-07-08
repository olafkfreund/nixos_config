# Enhanced Hyprland Window Rules Configuration
# Converted to native Nix configuration with feature flags and smart defaults
{
  config,
  lib,
  host ? "default",
  ...
}:
with lib; 
let
  # Import host-specific variables if available
  hostVars = 
    if builtins.pathExists ../../../../hosts/${host}/variables.nix
    then import ../../../../hosts/${host}/variables.nix
    else {};
  
  # Window management feature flags
  cfg = {
    # Terminal behavior
    terminals = {
      float = true;
      size = { width = 1000; height = 1000; };
      center = true;
      animations = true;
    };
    
    # Application workspace assignments
    workspaces = {
      useSpecialWorkspaces = true;
      assignments = {
        browsers = {
          chrome = "special:chrome";
          firefox = "special:firefox"; 
          edge = 4;
          zen = 4;
        };
        communication = {
          slack = "special:slack";
          discord = "special:discord";
          telegram = 8;
          thunderbird = "special:mail";
          teams = "special:slack";
          zoom = "special:slack";
          whatsapp = 8;
          signal = 8;
        };
        development = {
          vscode = 2;
          code = 2;
          tmux = "special:tmux";
          docker = 2;
          gitkraken = 2;
          dbeaver = 2;
          postman = 2;
        };
        media = {
          spotify = "special:spotify";
          obs = 4;
        };
        productivity = {
          obsidian = 5;
          notion = 5;
          libreoffice = 5;
        };
        gaming = {
          steam = 9;
          lutris = 9;
          heroic = 9;
          bottles = 9;
        };
        system = {
          "1password" = "special:magic";
          "org.1password.1password" = "special:magic";
        };
      };
    };
    
    # System utility behaviors  
    system = {
      floatUtilities = true;
      centerDialogs = true;
      dimAround = true;
    };
    
    # Gaming optimizations
    gaming = {
      immediateMode = true;
      fullscreenBorders = true;
    };
  };
  
  # Helper function to safely convert workspace assignments to strings
  workspaceToString = workspace: 
    if builtins.isString workspace 
    then workspace 
    else toString workspace;
  
  # Helper functions for generating rules
  mkRule = rule: conditions: "${rule}, ${conditions}";
  mkFloat = conditions: mkRule "float" conditions;
  mkSize = width: height: conditions: mkRule "size ${toString width} ${toString height}" conditions;
  mkWorkspace = workspace: conditions: mkRule "workspace ${workspaceToString workspace}" conditions;
  mkCenter = conditions: mkRule "center" conditions;
  mkAnimation = anim: conditions: mkRule "animation ${anim}" conditions;
  
  # Smart sizing based on screen resolution (defaults to 1920x1080)
  screenWidth = hostVars.screenWidth or 1920;
  screenHeight = hostVars.screenHeight or 1080;
  
  # Responsive sizing functions
  mkSmartSize = percentage: conditions: 
    let
      width = toString (screenWidth * percentage / 100);
      height = toString (screenHeight * percentage / 100);
    in mkRule "size ${width} ${height}" conditions;
  
  mkSmartFloat = percentage: conditions: [
    (mkFloat conditions)
    (mkSmartSize percentage conditions)
    (mkCenter conditions)
  ];
  
  # Terminal size calculation
  terminalSize = {
    width = toString cfg.terminals.size.width;
    height = toString cfg.terminals.size.height;
  };
  
  # Generate rules for multiple applications
  mkMultiRule = rule: apps: map (app: "${rule}, ${app}") apps;
  
  # Generate workspace assignments
  mkWorkspaceRules = assignments: 
    lib.flatten (lib.mapAttrsToList (category: apps:
      lib.mapAttrsToList (app: workspace: 
        mkWorkspace workspace "class:^(${app})$"
      ) apps
    ) assignments);

in {
  wayland.windowManager.hyprland.settings = {
    # Window rules using the modern windowrulev2 format
    windowrulev2 = lib.flatten [
      # =============================================================================
      # GLOBAL SETTINGS
      # =============================================================================
      # Disable hyprbars titlebar for specific windows
      "plugin:hyprbars:nobar, class:(album-art)"

      # =============================================================================
      # TERMINAL EMULATOR RULES
      # =============================================================================
      # Terminal emulators - use configuration-based sizing and behavior
    ] ++ lib.optionals cfg.terminals.float (lib.flatten [
      # Terminal emulators with smart sizing
      (mkMultiRule "float" ["class:(alacritty)" "class:(kitty)" "class:(wezterm)" "class:(foot)"])
      (mkMultiRule "size ${terminalSize.width} ${terminalSize.height}" ["class:(alacritty)" "class:(kitty)" "class:(wezterm)" "class:(foot)"])
    ]) ++ lib.optionals (cfg.terminals.center && cfg.terminals.float) (lib.flatten [
      (mkMultiRule "center" ["class:(alacritty)" "class:(kitty)" "class:(wezterm)" "class:(foot)"])
    ]) ++ lib.optionals (cfg.terminals.animations && cfg.terminals.float) [
      "animation slide left, class:^(foot)$"
    ] ++ [
      # Web search utility
      "float, class:(web-search)"
      "size ${terminalSize.width} ${terminalSize.height}, class:(web-search)"
      "animation slide down, class:^(web-search)$"

      # =============================================================================
      # SYSTEM UTILITY RULES
      # =============================================================================
      # System utilities stay in current workspace
      "workspace current, title:MainPicker"
      "workspace current, class:.blueman-manager-wrapped"
      "workspace current, class:xdg-desktop-portal-gtk"

      # Bluetooth manager
      "float, class:(blueman-manager)"
      "center, class:(blueman-manager)"
    ] ++ (mkSmartFloat 40 "class:(blueman-manager)") ++ [

      # Network utilities
      "float, class:^(nm-applet)$"
      "float, class:^(nm-connection-editor)$"
    ] ++ (mkSmartFloat 50 "class:^(nm-connection-editor)$") ++ [

      # Sound control (PulseAudio Volume Control)
    ] ++ (mkSmartFloat 60 "class:(org.pulseaudio.pavucontrol)") ++ [

      # XDG desktop portal
      "float, class:^(xdg-desktop-portal-gtk)$"
      "dimaround, class:^(xdg-desktop-portal-gtk)$"
      "center, class:^(xdg-desktop-portal-gtk)$"
    ] ++ (mkSmartFloat 45 "class:^(xdg-desktop-portal-gtk)$") ++ [
      
      # System monitors and task managers
      "float, class:^(htop)$"
      "float, class:^(btop)$"
      "float, class:^(mission-center)$"
      "float, class:^(gnome-system-monitor)$"
    ] ++ (mkSmartFloat 70 "class:^(htop)$") ++ [
    ] ++ (mkSmartFloat 70 "class:^(btop)$") ++ [
    ] ++ (mkSmartFloat 75 "class:^(mission-center)$") ++ [
    ] ++ (mkSmartFloat 70 "class:^(gnome-system-monitor)$") ++ [
      
      # File managers
      "float, class:^(thunar)$, title:^(.*)(Properties)(.*)$"
      "float, class:^(thunar)$, title:^(.*)(Preferences)(.*)$"
      "float, class:^(nemo)$, title:^(.*)(Properties)(.*)$"
      "float, class:^(nautilus)$, title:^(.*)(Properties)(.*)$"
    ] ++ (mkSmartFloat 50 "class:^(thunar)$, title:^(.*)(Properties)(.*)$") ++ [
    ] ++ (mkSmartFloat 55 "class:^(thunar)$, title:^(.*)(Preferences)(.*)$") ++ [
    ] ++ (mkSmartFloat 50 "class:^(nemo)$, title:^(.*)(Properties)(.*)$") ++ [
    ] ++ (mkSmartFloat 50 "class:^(nautilus)$, title:^(.*)(Properties)(.*)$") ++ [

      # =============================================================================
      # APPLICATION LAUNCHERS
      # =============================================================================
      # Rofi application launcher
      "animation bounce, class:^(rofi)$"

      # =============================================================================
      # PRODUCTIVITY APPLICATIONS
      # =============================================================================
      # Obsidian note-taking application
      "workspace ${workspaceToString cfg.workspaces.assignments.productivity.obsidian}, class:(obsidian)"
      "float, class:(obsidian), title:^(.*)(Settings)(.*)$"
      "float, class:(obsidian), title:^(.*)(Community plugins)(.*)$"
      "float, class:(obsidian), title:^(.*)(Hotkeys)(.*)$"
    ] ++ (mkSmartFloat 60 "class:(obsidian), title:^(.*)(Settings)(.*)$") ++ [
    ] ++ (mkSmartFloat 70 "class:(obsidian), title:^(.*)(Community plugins)(.*)$") ++ [
    ] ++ (mkSmartFloat 65 "class:(obsidian), title:^(.*)(Hotkeys)(.*)$") ++ [
      
      # Notion
      "float, class:^(notion)$"
      "workspace ${workspaceToString cfg.workspaces.assignments.productivity.obsidian}, class:^(notion)$"
    ] ++ (mkSmartFloat 80 "class:^(notion)$") ++ [
      
      # LibreOffice applications
      "float, class:^(libreoffice)$, title:^(.*)(Options)(.*)$"
      "float, class:^(libreoffice)$, title:^(.*)(Properties)(.*)$"
      "float, class:^(libreoffice)$, title:^(.*)(Print)(.*)$"
    ] ++ (mkSmartFloat 60 "class:^(libreoffice)$, title:^(.*)(Options)(.*)$") ++ [
    ] ++ (mkSmartFloat 50 "class:^(libreoffice)$, title:^(.*)(Properties)(.*)$") ++ [
    ] ++ (mkSmartFloat 55 "class:^(libreoffice)$, title:^(.*)(Print)(.*)$") ++ [
      
      # Calculator applications
      "float, class:^(org.gnome.Calculator)$"
      "float, class:^(galculator)$"
      "float, class:^(qalculate)$"
    ] ++ (mkSmartFloat 30 "class:^(org.gnome.Calculator)$") ++ [
    ] ++ (mkSmartFloat 35 "class:^(galculator)$") ++ [
    ] ++ (mkSmartFloat 40 "class:^(qalculate)$") ++ [

      # =============================================================================
      # THUNDERBIRD EMAIL CLIENT
      # =============================================================================
      # Main Thunderbird window
      "workspace special:mail, class:^(thunderbird)$"
      "animation slide bottom, class:^(thunderbird)$"
      "float, class:^(thunderbird)$, title:^(Mozilla Thunderbird)$"
      "size 70% 70%, class:^(thunderbird)$, title:^(Mozilla Thunderbird)$"

      # Thunderbird dialog windows
      "float, class:^(thunderbird)$, title:^(.*)(Reminder)(.*)$"
      "float, class:^(thunderbird)$, title:^(.*)(Write)(.*)$"
      "float, class:^(thunderbird)$, title:^(.*)(Compose)(.*)$"
      "float, class:^(thunderbird)$, title:^(.*)(Calendar)(.*)$"
      "float, class:^(thunderbird)$, title:^(.*)(Event)(.*)$"
      "float, class:^(thunderbird)$, title:^(.*)(Properties)(.*)$"
      "float, class:^(thunderbird)$, title:^(.*)(Preferences)(.*)$"
      "float, class:^(thunderbird)$, title:^(.*)(Settings)(.*)$"
      "float, class:^(thunderbird)$, title:^(.*)(Add-ons)(.*)$"
      "float, class:^(thunderbird)$, title:^(.*)(About)(.*)$"
      "float, class:^(thunderbird)$, title:^(.*)(Quick Filter)(.*)$"

      # Common Thunderbird popup sizing (60%)
      "size 60% 60%, class:^(thunderbird)$, title:^(.*)(Write)(.*)$"
      "size 60% 60%, class:^(thunderbird)$, title:^(.*)(Compose)(.*)$"
      "center, class:^(thunderbird)$, title:^(.*)(Write)(.*)$"
      "center, class:^(thunderbird)$, title:^(.*)(Compose)(.*)$"

      # Smaller Thunderbird dialogs (50%)
      "size 50% 50%, class:^(thunderbird)$, title:^(.*)(Reminder)(.*)$"
      "size 50% 50%, class:^(thunderbird)$, title:^(.*)(Properties)(.*)$"
      "size 50% 50%, class:^(thunderbird)$, title:^(.*)(Event)(.*)$"
      "center, class:^(thunderbird)$, title:^(.*)(Reminder)(.*)$"
      "center, class:^(thunderbird)$, title:^(.*)(Properties)(.*)$"
      "center, class:^(thunderbird)$, title:^(.*)(Event)(.*)$"

      # Very small Thunderbird dialogs (40%)
      "size 40% 40%, class:^(thunderbird)$, title:^(.*)(About)(.*)$"
      "center, class:^(thunderbird)$, title:^(.*)(About)(.*)$"

      # =============================================================================
      # WEB BROWSERS AND COMMUNICATION
      # =============================================================================
      # Google Chrome
      "workspace special:chrome, float, class:(google-chrome)"

      # Common file dialogs
      "float, size 900 500, title:^(Choose Files)"
      "float, size 900 500, title:^(Sign in)"

      # Microsoft Edge
      "workspace 4, class:^(Edge)$"

      # Slack communication
      "workspace special:slack, float, class:^(Slack)"
      "workspace special:slack, size 50% 50%, float, class:^(Slack), title:^(Huddle)"

      # Discord communication (using Vesktop)
      "workspace special:discord, float, class:^(vesktop)"
    ] ++ (mkSmartFloat 75 "class:^(vesktop)") ++ [
      "workspace special:discord, float, class:^(discord)"
    ] ++ (mkSmartFloat 75 "class:^(discord)") ++ [

      # Telegram messaging
      "workspace ${workspaceToString cfg.workspaces.assignments.communication.telegram}, class:(org.telegram.desktop)"
    ] ++ (mkSmartFloat 55 "class:(org.telegram.desktop), title:(Choose Files)") ++ [
      
      # WhatsApp
      "float, class:^(whatsapp)$"
      "workspace ${workspaceToString cfg.workspaces.assignments.communication.telegram}, class:^(whatsapp)$"
    ] ++ (mkSmartFloat 70 "class:^(whatsapp)$") ++ [
      
      # Signal
      "float, class:^(signal)$"
      "workspace ${workspaceToString cfg.workspaces.assignments.communication.telegram}, class:^(signal)$"
    ] ++ (mkSmartFloat 65 "class:^(signal)$") ++ [
      
      # Microsoft Teams
      "float, class:^(teams)$"
      "workspace ${workspaceToString cfg.workspaces.assignments.communication.slack}, class:^(teams)$"
    ] ++ (mkSmartFloat 80 "class:^(teams)$") ++ [
      
      # Zoom
      "float, class:^(zoom)$"
      "workspace ${workspaceToString cfg.workspaces.assignments.communication.slack}, class:^(zoom)$"
    ] ++ (mkSmartFloat 75 "class:^(zoom)$") ++ [
      "float, class:^(zoom)$, title:^(.*)(Settings)(.*)$"
    ] ++ (mkSmartFloat 60 "class:^(zoom)$, title:^(.*)(Settings)(.*)$") ++ [

      # =============================================================================
      # DEVELOPMENT TOOLS
      # =============================================================================
      # Visual Studio Code
      "workspace ${workspaceToString cfg.workspaces.assignments.development.vscode}, class:^(code)$"
      "workspace ${workspaceToString cfg.workspaces.assignments.development.vscode}, class:^(Code)$"
      "workspace ${workspaceToString cfg.workspaces.assignments.development.vscode}, class:^(code-url-handler)$"
      
      # VS Code dialogs and popups
    ] ++ (mkSmartFloat 60 "class:^(code)$, title:^(.*)(Settings)(.*)$") ++ [
    ] ++ (mkSmartFloat 70 "class:^(code)$, title:^(.*)(Extensions)(.*)$") ++ [
    ] ++ (mkSmartFloat 50 "class:^(code)$, title:^(.*)(Quick Open)(.*)$") ++ [
      
      # Development containers and Docker Desktop
      "float, class:^(Docker Desktop)$"
      "workspace ${workspaceToString cfg.workspaces.assignments.development.vscode}, class:^(Docker Desktop)$"
    ] ++ (mkSmartFloat 80 "class:^(Docker Desktop)$") ++ [
      
      # Git GUI applications
      "float, class:^(GitKraken)$"
      "workspace ${workspaceToString cfg.workspaces.assignments.development.vscode}, class:^(GitKraken)$"
    ] ++ (mkSmartFloat 85 "class:^(GitKraken)$") ++ [
      
      # Database tools
      "float, class:^(DBeaver)$"
      "workspace ${workspaceToString cfg.workspaces.assignments.development.vscode}, class:^(DBeaver)$"
    ] ++ (mkSmartFloat 80 "class:^(DBeaver)$") ++ [
      
      # Postman API testing
      "float, class:^(Postman)$"
      "workspace ${workspaceToString cfg.workspaces.assignments.development.vscode}, class:^(Postman)$"
    ] ++ (mkSmartFloat 75 "class:^(Postman)$") ++ [
      
      # Tmux scratchpad terminal
      "workspace special:tmux, float, title:^(tmux-sratch)"
      
      # Development terminal sessions
      "workspace ${workspaceToString cfg.workspaces.assignments.development.vscode}, class:^(dev-terminal)$"
      "float, class:^(dev-terminal)$"
    ] ++ (mkSmartFloat 70 "class:^(dev-terminal)$") ++ [

      # =============================================================================
      # ENTERTAINMENT APPLICATIONS
      # =============================================================================
      # Spotify music player
      "workspace special:spotify, float, class:^(spotify)"
      "workspace special:spotify, class:^(Spotify)$"

      # =============================================================================
      # PASSWORD MANAGEMENT
      # =============================================================================
      # 1Password password manager
      "workspace special:magic, float, class:^(1Password)$"
      "workspace special:magic, float, class:^(org.1password.1password)$"
      "float, class:^(1Password)$, title:^(.*)(Preferences)(.*)$"
      "center, class:^(1Password)$, title:^(.*)(Preferences)(.*)$"
      "size 50% 50%, class:^(1Password)$, title:^(.*)(Preferences)(.*)$"

      # =============================================================================
      # VIRTUALIZATION
      # =============================================================================
      # Virtual Machine Manager
      "float, class:(.virt-manager-wrapped)"
      "size 1000 1000, class:(.virt-manager-wrapped)"

      # =============================================================================
      # SYSTEM APPLICATIONS
      # =============================================================================
      # GNOME applications
      "float, class:(org.gnome.*)"
      "size 1000 1000, class:(org.gnome.*)"
      "center, class:(org.gnome.*)"

      # GNOME Calendar specific positioning
      "animation slide up, class:^(org.gnome.Calendar)$"
      "size 400 500, class:^(org.gnome.Calendar)$"
      "move 480 45, class:^(org.gnome.Calendar)$"

      # Camera controls
      "size 500 500, float, class:(hu.irl.cameractrls)"

      # Zen browser applications
      "size 70% 70%, float, class:(zen.alpha)$, title:^(.*)(Save)(.*)$"

      # =============================================================================
      # GAMING OPTIMIZATIONS
      # =============================================================================
    ] ++ lib.optionals cfg.gaming.immediateMode [
      # Enable immediate mode for games (reduced input latency)
      "immediate, class:^(cs2)$"
      "immediate, class:^(steam_app_).*$"
      "immediate, class:^(steam_proton)$"
      "immediate, class:^(lutris)$"
      "immediate, class:^(heroic)$"
      "immediate, class:^(bottles)$"
      "immediate, class:^(.*)(.exe)$"
      "immediate, class:^(wine)$"
      "immediate, class:^(Steam)$"
      
      # Disable compositor features for games
      "noblur, class:^(steam_app_).*$"
      "noblur, class:^(cs2)$"
      "noblur, class:^(lutris)$"
      "noblur, class:^(heroic)$"
      
      # Maximize gaming performance
      "noborder, class:^(steam_app_).*$"
      "noshadow, class:^(steam_app_).*$"
      "noanim, class:^(steam_app_).*$"
    ] ++ lib.optionals cfg.gaming.fullscreenBorders [
      # Gaming fullscreen optimizations
      "bordercolor rgba(FF0050FF), fullscreen:1"
      "bordersize 2, fullscreen:1"
    ] ++ [
      
      # Steam application
      "float, class:^(Steam)$, title:^(.*)(Settings)(.*)$"
      "float, class:^(Steam)$, title:^(.*)(Friends)(.*)$"
      "float, class:^(Steam)$, title:^(.*)(Screenshot)(.*)$"
    ] ++ (mkSmartFloat 70 "class:^(Steam)$, title:^(.*)(Settings)(.*)$") ++ [
    ] ++ (mkSmartFloat 40 "class:^(Steam)$, title:^(.*)(Friends)(.*)$") ++ [
      
      # Gaming launchers
      "float, class:^(lutris)$"
      "float, class:^(heroic)$"
      "float, class:^(bottles)$"
    ] ++ (mkSmartFloat 60 "class:^(lutris)$") ++ [
    ] ++ (mkSmartFloat 70 "class:^(heroic)$") ++ [
    ] ++ (mkSmartFloat 65 "class:^(bottles)$") ++ [

      # =============================================================================
      # SCREEN SHARING / RECORDING
      # =============================================================================
      # XWayland video bridge (invisible for screen sharing)
      "opacity 0.0 override, class:^(xwaylandvideobridge)$"
      "noanim, class:^(xwaylandvideobridge)$"
      "noinitialfocus, class:^(xwaylandvideobridge)$"
      "maxsize 1 1, class:^(xwaylandvideobridge)$"
      "noblur, class:^(xwaylandvideobridge)$"

      # =============================================================================
      # SCREEN CAPTURE AND EDITING
      # =============================================================================
      # Flameshot screenshot tool
      "float, class:^(flameshot)$"
      "pin, class:^(flameshot)$"
      "move 0 0, title:^(flameshot)$"
      "suppressevent fullscreen, class:^(flameshot)$"

      # OBS Studio
      "float, class:^(com.obsproject.Studio)$"
      "workspace 4, class:^(com.obsproject.Studio)$"

      # =============================================================================
      # WEATHER POPUP RULES
      # =============================================================================
      # Weather popup window behavior
      "float, title:^(Weather - London)$"
      "center, title:^(Weather - London)$"
      "size 900 700, title:^(Weather - London)$"
      "opacity 0.95, title:^(Weather - London)$"
      "rounding 10, title:^(Weather - London)$"
      "pin, title:^(Weather - London)$"
      "stayfocused, title:^(Weather - London)$"
      "dimaround, title:^(Weather - London)$"
      "animation slide, title:^(Weather - London)$"

      # Weather popup class-based rules for reliability
      "float, class:^(weather-popup)$"
      "center, class:^(weather-popup)$"
      "opacity 0.95, class:^(weather-popup)$"
      "rounding 10, class:^(weather-popup)$"
      "pin, class:^(weather-popup)$"
    ] ++ (mkSmartFloat 45 "class:^(weather-popup)$") ++ [
      
      # =============================================================================
      # WORKSPACE ASSIGNMENTS (Generated from Configuration)
      # =============================================================================
    ] ++ lib.optionals cfg.workspaces.useSpecialWorkspaces 
      (mkWorkspaceRules cfg.workspaces.assignments) ++ [
      
      # =============================================================================
      # ACCESSIBILITY AND SYSTEM UTILITIES
      # =============================================================================
      # Screen reader and accessibility tools
      "float, class:^(orca)$"
      "pin, class:^(orca)$"
    ] ++ (mkSmartFloat 40 "class:^(orca)$") ++ [
      
      # System configuration tools
      "float, class:^(gnome-control-center)$"
      "float, class:^(systemsettings)$"
    ] ++ (mkSmartFloat 70 "class:^(gnome-control-center)$") ++ [
    ] ++ (mkSmartFloat 75 "class:^(systemsettings)$") ++ [
      
      # Package managers
      "float, class:^(pamac)$"
      "float, class:^(discover)$"
      "float, class:^(gnome-software)$"
    ] ++ (mkSmartFloat 80 "class:^(pamac)$") ++ [
    ] ++ (mkSmartFloat 75 "class:^(discover)$") ++ [
    ] ++ (mkSmartFloat 75 "class:^(gnome-software)$") ++ [
    ];

    # Legacy window rules (minimal, for compatibility)
    windowrule = lib.optionals cfg.gaming.fullscreenBorders [
      "bordercolor rgba(FF0050FF), fullscreen:1"
    ];
  };
}
