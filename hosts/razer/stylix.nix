{ self, lib, config, pkgs, ... }: {

stylix.base16Scheme = "${pkgs.base16-schemes}/share/themes/gruvbox-dark-hard.yaml";
  
  stylix.image = ./gruvbox-rainbow-nix.png;

  stylix.fonts = {
    monospace = {
      package = pkgs.nerdfonts.override {fonts = ["JetBrainsMono"];};
      name = "JetBrainsMono Nerd Font Mono";
    };
    sansSerif = {
      package = pkgs.dejavu_fonts;
      name = "DejaVu Sans";
    };
    serif = {
      package = pkgs.dejavu_fonts;
      name = "DejaVu Serif";
    };
  };
  stylix.fonts.sizes = {
    applications = 12;
    terminal = 16;
    desktop = 10;
    popups = 10;
  };

  stylix.opacity = {
    applications = 0.8;
    terminal = 0.7;
    desktop = 1.0;
    popups = 1.0;
  };
  
  stylix.targets.chromium.enable = false;

}
