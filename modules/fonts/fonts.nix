{pkgs, ...}: {
  #---------------------------------------------------------------------
  # Font configuration
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
      # Using specific nerd fonts instead of a global package
      nerd-fonts.jetbrains-mono
      nerd-fonts.fira-code
      nerd-fonts.symbols-only # Fixed: use symbols-only instead of symbols
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-emoji
      ubuntu_font_family
      dejavu_fonts
      noto-fonts-lgc-plus
      texlivePackages.hebrew-fonts
      powerline-symbols
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
      localConf = ''
        <?xml version="1.0"?>
        <!DOCTYPE fontconfig SYSTEM "fonts.dtd">
        <fontconfig>
            <alias binding="weak">
                <family>monospace</family>
                <prefer>
                    <family>JetBrainsMono Nerd Font</family>
                    <family>JetBrainsMono Nerd Font Mono</family>
                    <family>Noto Color Emoji</family>
                    <family>Symbols Nerd Font</family>
                </prefer>
            </alias>
            <alias binding="weak">
                <family>sans-serif</family>
                <prefer>
                    <family>Noto Sans</family>
                    <family>Noto Color Emoji</family>
                </prefer>
            </alias>
            <alias binding="weak">
                <family>serif</family>
                <prefer>
                    <family>Noto Serif</family>
                    <family>Noto Color Emoji</family>
                </prefer>
            </alias>

            <!-- Force hint level for better appearance -->
            <match target="font">
                <edit name="hintstyle" mode="assign">
                    <const>hintslight</const>
                </edit>
            </match>

            <!-- Enable font antialiasing -->
            <match target="pattern">
                <edit name="antialias" mode="assign">
                    <bool>true</bool>
                </edit>
            </match>
        </fontconfig>
      '';
    };
  };
}
