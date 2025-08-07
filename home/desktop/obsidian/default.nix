{
  config,
  lib,
  ...
}:
with lib; let
  cfg = config.desktop.obsidian;
in {
  options.desktop.obsidian = {
    enable = mkEnableOption {
      default = false;
      description = "Obsidian markdown editor with Wayland optimizations";
    };
  };

  config = mkIf cfg.enable {
    # Create a desktop entry that uses our optimized launcher
    xdg.desktopEntries.obsidian-wayland = {
      name = "Obsidian (Wayland)";
      exec = "obsidian-wayland %F";
      icon = "obsidian";
      comment = "Knowledge base that works on top of a local folder of plain text Markdown files";
      genericName = "Note Taking";
      categories = ["Office" "Utility"];
      mimeType = ["text/markdown" "x-scheme-handler/obsidian"];
    };
  };
}
