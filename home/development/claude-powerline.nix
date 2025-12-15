{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.programs.claude-powerline;

  # Gruvbox Dark theme configuration
  themeConfig = {
    theme = "custom";
    colors = {
      # Background colors
      background = "#282828"; # dark0 (main background)
      backgroundAlt = "#3c3836"; # dark1
      backgroundDark = "#1d2021"; # dark0_hard

      # Foreground colors
      foreground = "#ebdbb2"; # light1 (main foreground)
      foregroundAlt = "#d5c4a1"; # light2
      foregroundDark = "#bdae93"; # light3

      # Accent colors (bright variants)
      red = "#fb4934"; # bright_red
      redDim = "#cc241d"; # normal_red
      green = "#b8bb26"; # bright_green
      greenDim = "#98971a"; # normal_green
      yellow = "#fabd2f"; # bright_yellow
      yellowDim = "#d79921"; # normal_yellow
      blue = "#83a598"; # bright_blue
      blueDim = "#458588"; # normal_blue
      purple = "#d3869b"; # bright_purple
      purpleDim = "#b16286"; # normal_purple
      aqua = "#8ec07c"; # bright_aqua
      aquaDim = "#689d6a"; # normal_aqua
      orange = "#fe8019"; # bright_orange
      orangeDim = "#d65d0e"; # normal_orange
      gray = "#928374"; # gray

      # UI elements
      separator = "#504945"; # dark2
      border = "#665c54"; # dark3
    };

    display = {
      inherit (cfg) style;
      charset = "unicode";
      autoWrap = true;

      # Single-line layout focused on development context (MAX subscription - no budget monitoring needed)
      lines = [
        {
          segments = {
            directory = {
              enabled = true;
              style = {
                background = "#458588"; # Blue - current directory
                foreground = "#282828"; # Dark background for contrast
              };
            };
            git = {
              enabled = true;
              style = {
                background = "#98971a"; # Green - git status
                foreground = "#282828";
              };
            };
            model = {
              enabled = true;
              style = {
                background = "#b16286"; # Purple - Claude model
                foreground = "#282828";
              };
            };
          };
        }
      ];
    };

    # Budget monitoring disabled (MAX subscription with unlimited usage)
  };

  # Write theme configuration to JSON file
  themeFile = pkgs.writeText "claude-powerline-gruvbox.json"
    (builtins.toJSON themeConfig);
in
{
  options.programs.claude-powerline = {
    enable = mkEnableOption "Claude Powerline statusline with Gruvbox Dark theme";

    theme = mkOption {
      type = types.enum [ "dark" "light" "nord" "tokyo-night" "rose-pine" "gruvbox" "custom" ];
      default = "custom";
      description = ''
        Theme to use for Claude Powerline.

        Built-in themes: dark, light, nord, tokyo-night, rose-pine, gruvbox
        Custom theme uses Gruvbox Dark color palette defined in this module.
      '';
    };

    style = mkOption {
      type = types.enum [ "minimal" "powerline" "capsule" ];
      default = "powerline";
      description = ''
        Separator style for statusline segments.

        - minimal: Simple separators
        - powerline: Vim-style powerline separators (recommended)
        - capsule: Rounded capsule separators
      '';
    };

    budget = {
      session = mkOption {
        type = types.float;
        default = 10.0;
        description = ''
          Session budget limit in USD (5-hour rolling window).

          Recommended values:
          - Conservative: 5-10
          - Moderate: 10-20
          - Aggressive: 20-50
        '';
      };

      daily = mkOption {
        type = types.float;
        default = 25.0;
        description = ''
          Daily budget limit in USD.

          Recommended values:
          - Conservative: 10-25
          - Moderate: 25-50
          - Aggressive: 50-100
        '';
      };

      block = mkOption {
        type = types.float;
        default = 15.0;
        description = ''
          Block budget limit in USD.

          Used for tracking costs within specific time blocks.
        '';
      };
    };
  };

  config = mkIf cfg.enable {
    # Create theme configuration file in XDG config directory
    xdg.configFile."claude-powerline/config.json".source = themeFile;

    # Claude Code settings integration (uses ~/.config/claude-code/)
    xdg.configFile."claude-code/settings.json".text = builtins.toJSON {
      statusLine = {
        type = "command";
        command = "npx -y @owloops/claude-powerline@latest --style=${cfg.style}";
      };
    };

    # Ensure Node.js is available for npx
    home.packages = with pkgs; [
      nodejs_22
    ];

    # Environment variables for Claude Powerline configuration
    home.sessionVariables = {
      CLAUDE_POWERLINE_THEME = cfg.theme;
      CLAUDE_POWERLINE_STYLE = cfg.style;
      CLAUDE_POWERLINE_CONFIG = "${config.xdg.configHome}/claude-powerline/config.json";
    };
  };
}
