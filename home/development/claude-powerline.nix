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

      # Gruvbox statusline script — mirrors your Starship prompt layout:
      # OS icon · hostname · user · dir · shell · git branch/status · model · context
      file.".claude/statusline-gruvbox.sh" = {
        executable = true;
        text = ''
          #!/usr/bin/env bash
          # Claude Code status line - Gruvbox Dark theme
          # Mirrors Starship prompt: OS  hostname  user  dir  zsh  git  model  ctx

          # Gruvbox dark ANSI 256-color escapes (matches starship.toml gruvbox_dark palette)
          GRV_BG1="\e[48;5;237m"    # bg1  (#3c3836)
          GRV_BG2="\e[48;5;239m"    # bg2  (#504945)
          GRV_YELLOW="\e[38;5;214m" # color_yellow (#d79921)
          GRV_ORANGE="\e[38;5;208m" # color_orange (warm display orange)
          GRV_GREEN="\e[38;5;142m"  # color_green  (#98971a)
          GRV_BLUE="\e[38;5;109m"   # color_blue   (#458588)
          GRV_AQUA="\e[38;5;108m"   # color_aqua   (#689d6a)
          GRV_RED="\e[38;5;167m"    # color_red    (#cc241d)
          GRV_PURPLE="\e[38;5;175m" # color_purple (#b16286)
          GRV_FG0="\e[38;5;230m"    # color_fg0    (#f9f5d7)
          GRV_FG2="\e[38;5;246m"    # dimmed fg
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
          git_worktree=$(echo "$input" | ${pkgs.jq}/bin/jq -r '.workspace.git_worktree // empty')
          repo_name=$(echo "$input"    | ${pkgs.jq}/bin/jq -r '.workspace.repo | if . then .owner + "/" + .name else empty end')
          pr_num=$(echo "$input"       | ${pkgs.jq}/bin/jq -r '.pr.number // empty')
          pr_state=$(echo "$input"     | ${pkgs.jq}/bin/jq -r '.pr.review_state // empty')
          effort=$(echo "$input"       | ${pkgs.jq}/bin/jq -r '.effort.level // empty')

          segments=""

          # NixOS OS icon — matches starship [os] NixOS = " "
          segments+="''${GRV_FG0}  ''${RESET}"

          # Hostname — matches starship [hostname] style=bold fg:color_purple
          hostname_short=$(${pkgs.hostname}/bin/hostname -s 2>/dev/null)
          if [ -n "$hostname_short" ]; then
            segments+="''${GRV_BG1}''${GRV_PURPLE}''${BOLD} ''${hostname_short} ''${RESET}"
          fi

          # Username — matches starship [username] aliases olafkfreund→olaf, style=bold fg:color_green
          whoami_out=$(${pkgs.coreutils}/bin/whoami 2>/dev/null)
          if [ -n "$whoami_out" ]; then
            [ "$whoami_out" = "olafkfreund" ] && display_user="olaf" || display_user="$whoami_out"
            segments+="''${GRV_BG1}''${GRV_GREEN}''${BOLD} ''${display_user} ''${RESET}"
          fi

          # CWD — matches starship [directory] style=bold fg:color_blue, truncation_length=2, home_symbol=~
          if [ -n "$cwd" ]; then
            short_cwd="''${cwd/#$HOME/~}"
            depth=$(echo "$short_cwd" | tr -cd '/' | wc -c)
            if [ "$depth" -gt 2 ]; then
              short_cwd="…/$(echo "$short_cwd" | rev | cut -d'/' -f1-2 | rev)"
            fi
            segments+="''${GRV_BG1}''${GRV_BLUE}''${BOLD} ''${short_cwd} ''${RESET}"
          fi

          # Shell indicator — matches starship [shell] zsh_indicator="zsh", style=fg:color_aqua
          segments+="''${GRV_AQUA} zsh ''${RESET}"

          # Git branch — matches starship [git_branch] symbol=" ", style=bold fg:color_purple
          git_branch=""
          if [ -n "$cwd" ]; then
            git_branch=$(${pkgs.git}/bin/git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null \
                         || ${pkgs.git}/bin/git -C "$cwd" rev-parse --short HEAD 2>/dev/null)
          fi
          if [ -n "$git_branch" ]; then
            git_status_flags=""
            if [ -n "$cwd" ]; then
              modified=$(${pkgs.git}/bin/git -C "$cwd" status --porcelain 2>/dev/null | grep -c '^ M\|^M ' || true)
              untracked=$(${pkgs.git}/bin/git -C "$cwd" status --porcelain 2>/dev/null | grep -c '^??' || true)
              staged=$(${pkgs.git}/bin/git -C "$cwd" status --porcelain 2>/dev/null | grep -c '^[MADRC]' || true)
              [ "$modified" -gt 0 ] 2>/dev/null   && git_status_flags+="!"
              [ "$untracked" -gt 0 ] 2>/dev/null  && git_status_flags+="?"
              [ "$staged" -gt 0 ] 2>/dev/null     && git_status_flags+="+''${staged}"
            fi
            git_label=" ''${git_branch}"
            [ -n "$git_status_flags" ] && git_label+=" ''${git_status_flags}"
            segments+="''${GRV_BG2}''${GRV_PURPLE}''${BOLD}''${git_label} ''${RESET}"
          fi

          # Git worktree (when in a linked worktree)
          if [ -n "$git_worktree" ]; then
            segments+="''${GRV_BG2}''${GRV_AQUA} worktree:''${git_worktree} ''${RESET}"
          fi

          # Repo (owner/name)
          if [ -n "$repo_name" ]; then
            segments+="''${GRV_BG2}''${GRV_FG2} ''${repo_name} ''${RESET}"
          fi

          # PR badge
          if [ -n "$pr_num" ]; then
            case "$pr_state" in
              approved)          pr_color="''${GRV_GREEN}"  ; pr_icon="" ;;
              changes_requested) pr_color="''${GRV_RED}"    ; pr_icon="" ;;
              draft)             pr_color="''${GRV_FG2}"    ; pr_icon="" ;;
              *)                 pr_color="''${GRV_YELLOW}" ; pr_icon="" ;;
            esac
            segments+="''${GRV_BG1}''${pr_color} ''${pr_icon}#''${pr_num} ''${RESET}"
          fi

          # Model — yellow for prominence
          if [ -n "$model" ]; then
            segments+="''${GRV_BG2}''${GRV_YELLOW} ''${model} ''${RESET}"
          fi

          # Session name (orange)
          if [ -n "$session" ]; then
            segments+="''${GRV_BG1}''${GRV_ORANGE} ''${session} ''${RESET}"
          fi

          # Effort level (when reasoning model is active)
          if [ -n "$effort" ]; then
            case "$effort" in
              low)       eff_color="''${GRV_FG2}" ;;
              high)      eff_color="''${GRV_YELLOW}" ;;
              xhigh|max) eff_color="''${GRV_RED}" ;;
              *)         eff_color="''${GRV_AQUA}" ;;
            esac
            segments+="''${GRV_BG2}''${eff_color} effort:''${effort} ''${RESET}"
          fi

          # Output style (purple) — only when non-default
          if [ -n "$output_style" ] && [ "$output_style" != "default" ] && [ "$output_style" != "Default" ]; then
            segments+="''${GRV_BG2}''${GRV_PURPLE} ''${output_style} ''${RESET}"
          fi

          # Vim mode — matches starship [character] vimcmd symbols
          if [ -n "$vim_mode" ]; then
            case "$vim_mode" in
              INSERT)        segments+="''${GRV_BG1}''${GRV_GREEN}''${BOLD} INSERT ''${RESET}" ;;
              NORMAL)        segments+="''${GRV_BG1}''${GRV_BLUE}''${BOLD} NORMAL ''${RESET}" ;;
              VISUAL)        segments+="''${GRV_BG1}''${GRV_PURPLE}''${BOLD} VISUAL ''${RESET}" ;;
              "VISUAL LINE") segments+="''${GRV_BG1}''${GRV_PURPLE}''${BOLD} V-LINE ''${RESET}" ;;
              *)             segments+="''${GRV_BG1}''${GRV_FG2} ''${vim_mode} ''${RESET}" ;;
            esac
          fi

          # Context window usage — color-coded green/yellow/red
          if [ -n "$used_pct" ]; then
            used_int=$(printf '%.0f' "$used_pct")
            if   [ "$used_int" -ge 80 ]; then ctx_color="''${GRV_RED}"
            elif [ "$used_int" -ge 50 ]; then ctx_color="''${GRV_YELLOW}"
            else                               ctx_color="''${GRV_GREEN}"
            fi
            segments+="''${GRV_BG2}''${ctx_color} ctx:''${used_int}% ''${RESET}"
          fi

          # Rate limits (subscribers only)
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
