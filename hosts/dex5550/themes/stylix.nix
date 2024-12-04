{pkgs, ...}: {
  stylix = {
    base16Scheme = "${pkgs.base16-schemes}/share/themes/gruvbox-dark-medium.yaml";
    image = ./gruv-abstract-maze.png;
    polarity = "dark";
    targets = {
      chromium.enable = false;
    };
    fonts = {
      monospace = {
        # A change is comming for the next release of NixOS
        package = pkgs.nerd-fonts.jetbrains-mono;
        # package = pkgs.nerdfonts.override {fonts = ["JetBrainsMono"];};
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
      sizes = {
        applications = 14;
        terminal = 14;
        desktop = 14;
        popups = 14;
      };
    };
    opacity = {
      applications = 1.0;
      terminal = 1.0;
      desktop = 1.0;
      popups = 1.0;
    };
  };
}
