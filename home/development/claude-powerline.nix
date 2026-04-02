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
    # Create theme configuration file
    xdg.configFile."claude-powerline/config.json".source = themeFile;

    # NOTE: ~/.claude/settings.json is NOT managed by Home Manager
    # It contains user-specific plugin settings that should not be overwritten.
    # Users must manually add the statusLine configuration to their existing settings.json:
    #
    # {
    #   "enabledPlugins": { ... },  // Keep existing plugin settings
    #   "statusLine": {
    #     "type": "command",
    #     "command": "$HOME/.claude/statusline-powerline.sh"
    #   }
    # }

    home = {
      # Create wrapper script for Claude Code statusLine (kept for compatibility)
      file.".claude/statusline-powerline.sh" = {
        text = ''
          #!/usr/bin/env bash
          # Claude Powerline statusline wrapper
          # Ensures proper environment and paths for npx

          # Set PATH to include nix profile binaries
          export PATH="${pkgs.nodejs_24}/bin:$PATH"

          # Pass stdin to claude-powerline with built-in gruvbox theme
          ${pkgs.nodejs_24}/bin/npx -y @owloops/claude-powerline@latest --style=${cfg.style} --theme=gruvbox
        '';
        executable = true;
      };

      # Gruvbox Dark native statusline script (no npm dependency)
      file.".claude/statusline-gruvbox.sh" = {
        text = ''
          #!/usr/bin/env bash
          # Claude Code status line - Gruvbox Dark theme
          # Pure bash implementation, no external npm dependencies
          #
          # Gruvbox dark (256-color ANSI palette):
          #   bg0=235  bg1=237  bg2=239
          #   fg1=223  fg4=246
          #   bright: red=167 green=142 yellow=214 blue=109 aqua=108 orange=208 purple=175

          GRV_BG1="\e[48;5;237m"
          GRV_BG2="\e[48;5;239m"
          GRV_FG2="\e[38;5;246m"
          GRV_YELLOW="\e[38;5;214m"
          GRV_ORANGE="\e[38;5;208m"
          GRV_GREEN="\e[38;5;142m"
          GRV_BLUE="\e[38;5;109m"
          GRV_AQUA="\e[38;5;108m"
          GRV_RED="\e[38;5;167m"
          GRV_PURPLE="\e[38;5;175m"
          RESET="\e[0m"
          BOLD="\e[1m"

          input=$(cat)

          cwd=$(echo "$input"          | ${pkgs.jq}/bin/jq -r '.cwd // empty')
          model=$(echo "$input"        | ${pkgs.jq}/bin/jq -r '.model.display_name // empty')
          session=$(echo "$input"      | ${pkgs.jq}/bin/jq -r '.session_name // empty')
          used_pct=$(echo "$input"     | ${pkgs.jq}/bin/jq -r '.context_window.used_percentage // empty')
          vim_mode=$(echo "$input"     | ${pkgs.jq}/bin/jq -r '.vim.mode // empty')
          output_style=$(echo "$input" | ${pkgs.jq}/bin/jq -r '.output_style.name // empty')
          five_h=$(echo "$input"       | ${pkgs.jq}/bin/jq -r '.rate_limits.five_hour.used_percentage // empty')
          seven_d=$(echo "$input"      | ${pkgs.jq}/bin/jq -r '.rate_limits.seven_day.used_percentage // empty')

          segments=""

          # CWD: bg1 + aqua
          if [ -n "$cwd" ]; then
            short_cwd="''${cwd/#$HOME/~}"
            segments+="''${GRV_BG1}''${GRV_AQUA}''${BOLD} ''${short_cwd} ''${RESET}"
          fi

          # Model: bg2 + yellow
          if [ -n "$model" ]; then
            segments+="''${GRV_BG2}''${GRV_YELLOW} ''${model} ''${RESET}"
          fi

          # Session name: bg1 + orange (only if set)
          if [ -n "$session" ]; then
            segments+="''${GRV_BG1}''${GRV_ORANGE} ''${session} ''${RESET}"
          fi

          # Output style: bg2 + purple (only if non-default)
          if [ -n "$output_style" ] && [ "$output_style" != "default" ] && [ "$output_style" != "Default" ]; then
            segments+="''${GRV_BG2}''${GRV_PURPLE} ''${output_style} ''${RESET}"
          fi

          # Vim mode: bg1 + green (INSERT) or blue (NORMAL)
          if [ -n "$vim_mode" ]; then
            case "$vim_mode" in
              INSERT) segments+="''${GRV_BG1}''${GRV_GREEN}''${BOLD} INSERT ''${RESET}" ;;
              NORMAL) segments+="''${GRV_BG1}''${GRV_BLUE}''${BOLD} NORMAL ''${RESET}" ;;
              *)      segments+="''${GRV_BG1}''${GRV_FG2} ''${vim_mode} ''${RESET}" ;;
            esac
          fi

          # Context usage: color-coded green/yellow/red
          if [ -n "$used_pct" ]; then
            used_int=$(printf '%.0f' "$used_pct")
            if [ "$used_int" -ge 80 ]; then
              ctx_color="''${GRV_RED}"
            elif [ "$used_int" -ge 50 ]; then
              ctx_color="''${GRV_YELLOW}"
            else
              ctx_color="''${GRV_GREEN}"
            fi
            segments+="''${GRV_BG2}''${ctx_color} ctx:''${used_int}% ''${RESET}"
          fi

          # Rate limits (5h and 7d, shown only when present)
          rate_seg=""
          if [ -n "$five_h" ]; then
            five_int=$(printf '%.0f' "$five_h")
            [ "$five_int" -ge 80 ] && rl_c="''${GRV_RED}" || rl_c="''${GRV_ORANGE}"
            rate_seg+="''${rl_c}5h:''${five_int}%''${RESET}"
          fi
          if [ -n "$seven_d" ]; then
            seven_int=$(printf '%.0f' "$seven_d")
            [ "$seven_int" -ge 80 ] && rl_c="''${GRV_RED}" || rl_c="''${GRV_FG2}"
            [ -n "$rate_seg" ] && rate_seg+=" "
            rate_seg+="''${rl_c}7d:''${seven_int}%''${RESET}"
          fi
          if [ -n "$rate_seg" ]; then
            segments+="''${GRV_BG1} ''${rate_seg} ''${RESET}"
          fi

          printf "%b" "''${segments}"
        '';
        executable = true;
      };

      # Ensure Node.js is available for npx
      packages = with pkgs; [
        nodejs_24
      ];

      # Environment variables for Claude Powerline configuration
      sessionVariables = {
        CLAUDE_POWERLINE_THEME = cfg.theme;
        CLAUDE_POWERLINE_STYLE = cfg.style;
        CLAUDE_POWERLINE_CONFIG = "${config.xdg.configHome}/claude-powerline/config.json";
      };
    };
  };
}
