{ config, pkgs, ... }:
let
  inherit (config.lib.stylix) colors;
  c = colors.withHashtag;

  # clipse has no Stylix target and reads a flat colour map from a JSON file
  # named by config.json's `themeFile`. Generating it from the active base16
  # scheme keeps the clipboard picker on the same palette as everything else;
  # it used to ship a checked-in theme file that never moved.
  #
  # Borders and accents are phosphor green rather than the blue the old
  # file used, matching the HUD's active-border convention.
  clipseTheme = {
    DimmedDesc = c.base04;
    DimmedTitle = c.base04;
    DividerDot = c.base0B;
    HelpDesc = c.base03;
    HelpKey = c.base0B;
    NormalDesc = c.base04;
    NormalTitle = c.base05;
    PageActiveDot = c.base0B;
    PageInactiveDot = c.base03;
    PreviewBorder = c.base0B;
    PreviewedText = c.base05;
    SelectedDesc = c.base04;
    SelectedDescBorder = c.base0B;
    SelectedTitle = c.base0B;
    StatusMsg = c.base08;
    TitleFore = c.base0B;
    TitleInfo = c.base04;
    useCustomTheme = true;
  };

  # Shell script to launch clipse in foot terminal with custom class
  open-clip = pkgs.writeShellScriptBin "open-clip" ''
    foot -a clipse -e 'clipse'
  '';
in
{
  home.packages = [
    pkgs.wl-clipboard
    open-clip
  ];

  home.file = {
    ".config/clipse/alien-hud.json".text = builtins.toJSON clipseTheme;
    ".config/clipse/config.json".source = ./config.json;
  };
}
