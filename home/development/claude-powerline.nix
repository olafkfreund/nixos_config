{ config, lib, pkgs, ... }:

let
  inherit (lib) mkIf mkEnableOption;
  cfg = config.programs.claude-powerline;
in
{
  options.programs.claude-powerline = {
    enable = mkEnableOption "Claude Powerline statusline with Gruvbox Dark theme";
  };

  config = mkIf cfg.enable {
    # ~/.claude/settings.json is NOT managed by Home Manager — it is
    # syncthing-synced and holds runtime plugin state. It points at
    # statusline-gruvbox.sh below; that wiring is done once, by hand.
    #
    # An @owloops/claude-powerline npx wrapper used to be generated here too,
    # but nothing ever referenced it: settings.json has always pointed at the
    # gruvbox script. It was also the wrong tool for this repo — it ran
    # `npx -y @owloops/claude-powerline@latest` on *every* statusline render,
    # i.e. an unpinned network fetch in the hot path of a NixOS config, and it
    # rendered no hostname segment (the one thing that matters most across
    # p620/razer/p510). Removed in #1159 along with its theme file and
    # CLAUDE_POWERLINE_CONFIG env var.

    home = {
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

    };
  };
}
