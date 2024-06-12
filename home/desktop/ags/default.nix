{ inputs, pkgs, ... }:

{

programs.ags = {
    enable = true;
    
    configDir = null;

    extraPackages = with pkgs; [
      gtksourceview
      webkitgtk
      accountsservice
    ];
  };

}
