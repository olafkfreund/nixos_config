{ pkgs, ... }: {
wayland.windowManager.sway = {
    enable = true;
    config =  {
      terminal = "kitty"; 
      startup = [
        {command = "kitty";}
      ];
    };
  };
}
