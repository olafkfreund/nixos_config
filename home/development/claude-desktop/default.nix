{ config, lib, pkgs, ... }:

{
  # Claude Desktop Application Entry
  # Provides a desktop launcher for Anthropic's Claude Desktop GUI application
  
  xdg.desktopEntries.claude-desktop = {
    name = "Claude Desktop";
    comment = "Anthropic's Claude AI Desktop Application";
    exec = "claude-desktop";
    icon = "applications-office"; # Generic office application icon
    terminal = false;
    type = "Application";
    categories = [ "Office" "Productivity" "Development" ];
    startupWMClass = "claude-desktop";
    
    # Additional metadata
    mimeType = [ ];
    keywords = [ "AI" "Claude" "Assistant" "Anthropic" "Chat" ];
    
    # Startup notification
    startupNotify = true;
    
    # Actions (optional - could add different startup modes in future)
    actions = { };
  };

  # Ensure claude-desktop is available in PATH
  # This is typically provided by the system configuration
  home.sessionPath = [ 
    "/run/current-system/sw/bin" 
  ];
}