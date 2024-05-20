{pkgs, inputs, ...}: {
  wayland.windowManager.hyprland = { 
    settings = {
      plugins = [
        inputs.hycov.packages.${pkgs.system}.hycov
      ];
      bind = [
        "ALT,tab,hycov:toggleoverview"
        "ALT,left,hycov:movefocus,l"
        "ALT,right,hycov:movefocus,r"
        "ALT,up,hycov:movefocus,u"
        "ALT,down,hycov:movefocus,d"
      ];
      plugin =  {
        hycov = {
          overview_gappo = 60; #gaps width from screen
          overview_gappi = 24; #gaps width from clients
          hotarea_size = 10; #hotarea size in bottom left,10x10
          enable_hotarea = 1; # enable mouse cursor hotarea
        };
      };
    };
  };
}
