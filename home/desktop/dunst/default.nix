{
  inputs,
  pkgs,
  config,
  ...
}:{
  services.dunst = {
    enable = true;
    settings = {
      global = {
        width = 300;
        height = 300;
        offset = "30x50";
        origin = "top-right";
        transparency = 10;
        # frame_color = "#${colors.base0E}";
        frame_color = "#a9b665DD";
        frame_width = 2;
        font = "JetBrainsMono Nerd Font Medium 8";
        corner_radius = 10;
      };

      urgency_normal = {
        foreground = "#bdae93";
        background = "#2a2827";
        timeout = 5;
      };
    };
  };
}