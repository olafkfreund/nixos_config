{pkgs, ...}: let
  # Shell script to launch clipse in foot terminal with custom class
  open-clip = pkgs.writeShellScriptBin "open-clip" ''
    foot -a clipse -e 'clipse'
  '';
in {
  home.packages = [
    pkgs.clipse
    pkgs.wl-clipboard
    open-clip
  ];

  home.file = {
    ".config/clipse/gruvbox.json".source = ./gruvbox.json;
    ".config/clipse/config.json".source = ./config.json;
  };

  wayland.windowManager.hyprland.settings = {
    exec-once = ["clipse -listen"];
    windowrulev2 = [
      "float,        class:(clipse)"
      "size 800 800, class:(clipse)"
    ];
  };
}
