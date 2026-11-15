{ config
, lib
, ...
}:
let
  inherit (lib) mkIf;
  cfg = config.features.desktop;
in
{

  config = mkIf (cfg.enable && cfg.obsidian) {
    # Create a desktop entry that uses our optimized launcher
    xdg.desktopEntries.obsidian-wayland = {
      name = "Obsidian (Wayland)";
      exec = "obsidian-wayland %F";
      icon = "obsidian";
      comment = "Knowledge base that works on top of a local folder of plain text Markdown files";
      genericName = "Note Taking";
      categories = [ "Office" "Utility" ];
      mimeType = [ "text/markdown" "x-scheme-handler/obsidian" ];
    };
  };
}
