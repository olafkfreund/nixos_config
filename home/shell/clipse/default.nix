{pkgs, ...}: let
  open-clip =
    pkgs.writers.writeNuBin "open-clip"
    (builtins.readFile ./open-clip.nu);

  # Shell script to launch clipse in foot terminal with custom class
  launch-clipse = pkgs.writeShellScriptBin "launch-clipse" ''
    foot --class clipse -e 'clipse'
  '';
in {
  home.packages = [
    pkgs.clipse
    pkgs.wl-clipboard
    open-clip
    launch-clipse
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
