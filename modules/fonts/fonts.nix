# System Font Configuration Module
# Provides comprehensive font packages and fontconfig settings
{ config
, lib
, pkgs
, ...
}:
with lib; let
  cfg = config.modules.fonts;
in
{
  options.modules.fonts = {
    enable = mkEnableOption "comprehensive font configuration";

    packages = {
      core = mkOption {
        type = types.bool;
        default = true;
        description = ''Enable core font packages (Noto, DejaVu, Ubuntu)'';
        example = false;
      };

      programming = mkOption {
        type = types.bool;
        default = true;
        description = ''Enable programming fonts (JetBrains Mono, Fira Code)'';
        example = false;
      };

      nerdFonts = mkOption {
        type = types.bool;
        default = true;
        description = ''Enable Nerd Fonts with icon support'';
        example = false;
      };

      cjk = mkOption {
        type = types.bool;
        default = false;
        description = ''Enable Chinese, Japanese, Korean font support'';
        example = true;
      };

      icons = mkOption {
        type = types.bool;
        default = true;
        description = ''Enable icon fonts (Font Awesome, Material Icons)'';
        example = false;
      };
    };

    fontconfig = {
      enableOptimizations = mkOption {
        type = types.bool;
        default = true;
        description = ''Enable fontconfig optimizations for better rendering'';
        example = false;
      };

      defaultMonospace = mkOption {
        type = types.str;
        default = "JetBrainsMono Nerd Font";
        description = ''Default monospace font family'';
        example = "Fira Code";
      };
    };
  };

  config = mkIf cfg.enable {
    fonts = {
      fontDir.enable = true;
      enableGhostscriptFonts = true;
      enableDefaultPackages = false;

      packages = with pkgs;
        # Core fonts
        optionals cfg.packages.core [
          corefonts
          dejavu_fonts
          noto-fonts
          noto-fonts-emoji
          ubuntu_font_family
          noto-fonts-lgc-plus
        ]
        ++
        # Programming fonts
        optionals cfg.packages.programming [
          fira
          fira-code
          fira-go
          jetbrains-mono
          powerline-symbols
        ]
        ++
        # Nerd Fonts
        optionals cfg.packages.nerdFonts [
          nerd-fonts.jetbrains-mono
          nerd-fonts.fira-code
          nerd-fonts.symbols-only
          nerd-fonts.caskaydia-cove
        ]
        ++
        # CJK fonts
        optionals cfg.packages.cjk [
          noto-fonts-cjk-sans
          texlivePackages.hebrew-fonts
        ]
        ++
        # Icon fonts
        optionals cfg.packages.icons [
          font-awesome
          material-design-icons
          material-icons
        ];

      fontconfig = mkMerge [
        { enable = true; }
        (mkIf cfg.fontconfig.enableOptimizations {
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
                        <family>${cfg.fontconfig.defaultMonospace}</family>
                        <family>${cfg.fontconfig.defaultMonospace} Mono</family>
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
        })
      ];
    };

    # Helpful warnings
    warnings = [
      (mkIf (!cfg.packages.core && !cfg.packages.programming) ''
        Font module is enabled but no core or programming fonts are selected.
        Consider enabling at least core fonts for basic system functionality.
      '')
    ];

    # Validation
    assertions = [
      {
        assertion = cfg.packages.nerdFonts -> cfg.packages.programming;
        message = "Nerd Fonts require programming fonts to be enabled for proper functionality";
      }
    ];
  };
}
