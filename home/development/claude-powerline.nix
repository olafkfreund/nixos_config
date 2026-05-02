{ config, lib, pkgs, ... }:

let
  inherit (lib) mkOption mkIf mkEnableOption types;
  cfg = config.programs.claude-powerline;
  inherit (config.lib.stylix) colors;

  # Gruvbox Dark theme configuration
  themeConfig = {
    theme = "custom";
    colors = {
      # Background colors
      background = "#${colors.base00}"; # dark0 (main background)
      backgroundAlt = "#${colors.base01}"; # dark1
      backgroundDark = "#${colors.base00}"; # dark0_hard

      # Foreground colors
      foreground = "#${colors.base06}"; # light1 (main foreground)
      foregroundAlt = "#${colors.base05}"; # light2
      foregroundDark = "#${colors.base04}"; # light3

      # Accent colors (bright variants)
      red = "#${colors.base08}"; # bright_red
      redDim = "#${colors.base08}"; # normal_red
      green = "#${colors.base0B}"; # bright_green
      greenDim = "#${colors.base0B}"; # normal_green
      yellow = "#${colors.base0A}"; # bright_yellow
      yellowDim = "#${colors.base0A}"; # normal_yellow
      blue = "#${colors.base0D}"; # bright_blue
      blueDim = "#${colors.base0D}"; # normal_blue
      purple = "#${colors.base0E}"; # bright_purple
      purpleDim = "#${colors.base0E}"; # normal_purple
      aqua = "#${colors.base0C}"; # bright_aqua
      aquaDim = "#${colors.base0C}"; # normal_aqua
      orange = "#${colors.base09}"; # bright_orange
      orangeDim = "#${colors.base0F}"; # normal_orange
      gray = "#${colors.base03}"; # gray

      # UI elements
      separator = "#${colors.base02}"; # dark2
      border = "#${colors.base03}"; # dark3
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
                background = "#${colors.base0D}"; # Blue - current directory
                foreground = "#${colors.base00}"; # Dark background for contrast
              };
            };
            git = {
              enabled = true;
              style = {
                background = "#${colors.base0B}"; # Green - git status
                foreground = "#${colors.base00}";
              };
            };
            model = {
              enabled = true;
              style = {
                background = "#${colors.base0E}"; # Purple - Claude model
                foreground = "#${colors.base00}";
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
      # Create wrapper script for Claude Code statusLine
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

      # Gruvbox statusline script (pure bash, no npx dependency)
      file.".claude/statusline-gruvbox.sh" = {
        executable = true;
        text = ''
          #!/usr/bin/env bash
          # Claude Code status line - Gruvbox Dark theme

          # Gruvbox dark ANSI 256-color escapes
          GRV_BG1="\e[48;5;237m"    # bg1
          GRV_BG2="\e[48;5;239m"    # bg2
          GRV_YELLOW="\e[38;5;214m" # bright yellow
          GRV_ORANGE="\e[38;5;208m" # bright orange
          GRV_GREEN="\e[38;5;142m"  # bright green
          GRV_BLUE="\e[38;5;109m"   # bright blue
          GRV_AQUA="\e[38;5;108m"   # bright aqua
          GRV_RED="\e[38;5;167m"    # bright red
          GRV_PURPLE="\e[38;5;175m" # bright purple
          GRV_FG2="\e[38;5;246m"    # fg4 (dimmed)
          RESET="\e[0m"
          BOLD="\e[1m"

          input=$(cat)

          cwd=$(echo "$input"        | ${pkgs.jq}/bin/jq -r '.cwd // empty')
          model=$(echo "$input"      | ${pkgs.jq}/bin/jq -r '.model.display_name // empty')
          session=$(echo "$input"    | ${pkgs.jq}/bin/jq -r '.session_name // empty')
          used_pct=$(echo "$input"   | ${pkgs.jq}/bin/jq -r '.context_window.used_percentage // empty')
          remain_pct=$(echo "$input" | ${pkgs.jq}/bin/jq -r '.context_window.remaining_percentage // empty')
          vim_mode=$(echo "$input"   | ${pkgs.jq}/bin/jq -r '.vim.mode // empty')
          output_style=$(echo "$input" | ${pkgs.jq}/bin/jq -r '.output_style.name // empty')
          five_h=$(echo "$input"     | ${pkgs.jq}/bin/jq -r '.rate_limits.five_hour.used_percentage // empty')
          seven_d=$(echo "$input"    | ${pkgs.jq}/bin/jq -r '.rate_limits.seven_day.used_percentage // empty')

          # Git branch (from cwd if available)
          git_branch=""
          if [ -n "$cwd" ] && [ -d "$cwd/.git" ] || git -C "$cwd" rev-parse --git-dir >/dev/null 2>&1; then
            git_branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null || git -C "$cwd" rev-parse --short HEAD 2>/dev/null)
          fi

          segments=""

          # CWD (bg1, aqua)
          if [ -n "$cwd" ]; then
            short_cwd="''${cwd/#$HOME/~}"
            segments+="''${GRV_BG1}''${GRV_AQUA}''${BOLD} ''${short_cwd} ''${RESET}"
          fi

          # Git branch (bg2, green)
          if [ -n "$git_branch" ]; then
            segments+="''${GRV_BG2}''${GRV_GREEN} ⎇ ''${git_branch} ''${RESET}"
          fi

          # Model (bg2, yellow)
          if [ -n "$model" ]; then
            segments+="''${GRV_BG2}''${GRV_YELLOW} ''${model} ''${RESET}"
          fi

          # Session name (bg1, orange)
          if [ -n "$session" ]; then
            segments+="''${GRV_BG1}''${GRV_ORANGE} ''${session} ''${RESET}"
          fi

          # Output style (bg2, purple) — only if non-default
          if [ -n "$output_style" ] && [ "$output_style" != "default" ] && [ "$output_style" != "Default" ]; then
            segments+="''${GRV_BG2}''${GRV_PURPLE} ''${output_style} ''${RESET}"
          fi

          # Vim mode (bg1, green/blue)
          if [ -n "$vim_mode" ]; then
            case "$vim_mode" in
              INSERT) segments+="''${GRV_BG1}''${GRV_GREEN}''${BOLD} INSERT ''${RESET}" ;;
              NORMAL) segments+="''${GRV_BG1}''${GRV_BLUE}''${BOLD} NORMAL ''${RESET}" ;;
              *)      segments+="''${GRV_BG1}''${GRV_FG2} ''${vim_mode} ''${RESET}" ;;
            esac
          fi

          # Context window usage
          if [ -n "$used_pct" ] && [ -n "$remain_pct" ]; then
            used_int=$(printf '%.0f' "$used_pct")
            if   [ "$used_int" -ge 80 ]; then ctx_color="''${GRV_RED}"
            elif [ "$used_int" -ge 50 ]; then ctx_color="''${GRV_YELLOW}"
            else                               ctx_color="''${GRV_GREEN}"
            fi
            segments+="''${GRV_BG2}''${ctx_color} ctx:''${used_int}% ''${RESET}"
          fi

          # Rate limits
          rate_seg=""
          if [ -n "$five_h" ]; then
            five_int=$(printf '%.0f' "$five_h")
            [ "$five_int" -ge 80 ] && rl_color="''${GRV_RED}" || rl_color="''${GRV_ORANGE}"
            rate_seg+="''${rl_color}5h:''${five_int}%''${RESET}"
          fi
          if [ -n "$seven_d" ]; then
            seven_int=$(printf '%.0f' "$seven_d")
            [ "$seven_int" -ge 80 ] && rl_color="''${GRV_RED}" || rl_color="''${GRV_FG2}"
            [ -n "$rate_seg" ] && rate_seg+=" "
            rate_seg+="''${rl_color}7d:''${seven_int}%''${RESET}"
          fi
          if [ -n "$rate_seg" ]; then
            segments+="''${GRV_BG1} ''${rate_seg} ''${RESET}"
          fi

          printf "%b" "''${segments}"
        '';
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
