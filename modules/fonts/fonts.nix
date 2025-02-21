{pkgs, ...}: {
  #---------------------------------------------------------------------
  # Custom fonts - Chris Titus && wimpysworld
  #---------------------------------------------------------------------

  fonts = {
    fontDir.enable = true;
    fontconfig.enable = true;
    enableGhostscriptFonts = true;

    packages = with pkgs; [
      corefonts
      dejavu_fonts
      fira
      fira-code
      fira-go
      font-awesome
      jetbrains-mono
      material-design-icons
      material-icons
      nerd-font-patcher
      nerdfonts
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-emoji
      ubuntu_font_family
    ];

    #---------------------------------------------------------------------
    # Enable a basic set of fonts providing several font styles and
    # families and reasonable coverage of Unicode.
    #---------------------------------------------------------------------

    enableDefaultPackages = false;

    fontconfig = {
      allowBitmaps = true;
      antialias = true;
      cache32Bit = true;
      useEmbeddedBitmaps = true;

      defaultFonts = {
        emoji = ["Joypixels" "Noto Color Emoji"];
        monospace = ["FiraCode Nerd Font Mono" "SauceCodePro Nerd Font Mono"];
        sansSerif = ["Work Sans" "Fira Sans" "FiraGO"];
        serif = ["Source Serif"];
      };

      hinting = {
        autohint = false;
        enable = true;
        style = "slight";
      };

      subpixel = {
        lcdfilter = "light";
        rgba = "rgb";
      };
    };
  };
}
