{ pkgs
, ...
}: {
  home.packages = with pkgs; [
    zsh
    oh-my-zsh
    zplug
    zsh-edit
    zsh-autopair
    zsh-clipboard
    any-nix-shell
  ];

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    syntaxHighlighting = {
      enable = true;
    };
    autosuggestion.enable = true;
    
    zplug = {
      enable = true;
      plugins = [
        {
          name = "loiccoyle/zsh-github-copilot";
        }
      ];
    };
    plugins = [
      {
        name = "zsh-fzf-tab";
        src = pkgs.zsh-fzf-tab;
        file = "share/fzf-tab/fzf-tab.plugin.zsh";
      }
      {
        name = "zsh-f-sy-h";
        src = pkgs.zsh-f-sy-h;
        file = "share/zsh/site-functions/F-Sy-H.plugin.zsh";
      }
      {
        name = "zsh-nix-shell";
        src = pkgs.zsh-nix-shell;
        file = "share/zsh-nix-shell/nix-shell.plugin.zsh";
      }
      {
        name = "zsh-forgit";
        src = pkgs.zsh-forgit;
        file = "share/zsh/zsh-forgit/forgit.plugin.zsh";
      }
      {
        name = "zsh-edit";
        src = pkgs.zsh-edit;
        file = "share/zsh-edit/zsh-edit.plugin.zsh";
      }
      {
        name = "zsh-autocomplete";
        src = pkgs.zsh-autocomplete;
        file = "share/zsh-autocomplete/zsh-autocomplete.plugin.zsh";
      }
      {
        name = "zsh-syntax-highlighting";
        src = pkgs.zsh-syntax-highlighting;
        file = "share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh";
      }
      {
        name = "nix-zsh-completions";
        src = pkgs.nix-zsh-completions;
        file = "share/zsh/plugins/nix/nix-zsh-completions.plugin.zsh";
      }
      {
        name = "zsh-you-should-use";
        src = pkgs.zsh-you-should-use;
        file = "share/zsh/plugins/you-should-use/you-should-use.plugin.zsh";
      }
      {
        name = "zsh-autosuggestions";
        src = pkgs.zsh-autosuggestions;
        file = "share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.plugin.zsh";
      }
    ];

    initExtraBeforeCompInit = ''
      fpath+=(${pkgs.zsh-completions}/share/zsh/site-functions)
    '';

    completionInit = ''
      # Load Zsh modules
      zmodload zsh/zle
      zmodload zsh/zpty
      zmodload zsh/complist

      # Initialize colors
      autoload -Uz colors
      colors

      # Initialize completion system
      autoload -U compinit
      compinit
      _comp_options+=(globdots)

      # C-right / C-left for word skips
      bindkey "^[[1;5C" forward-word
      bindkey "^[[1;5D" backward-word

      # C-Backspace / C-Delete for word deletions
      bindkey "^[[3;5~" forward-kill-word
      bindkey "^H" backward-kill-word

      # Home/End
      # bindkey '^[[3~' delete-char                     # Key Del
      # bindkey '^[[5~' beginning-of-buffer-or-history  # Key Page Up
      # bindkey '^[[6~' end-of-buffer-or-history        # Key Page Down
      # bindkey '^[[1;3D' backward-word                 # Key Alt + Left
      # bindkey '^[[1;3C' forward-word                  # Key Alt + Right
      # bindkey '^[[H' beginning-of-line                # Key Home
      # bindkey '^[[F' end-of-line                      # Key end-of-line
      
      bindkey '^[|' zsh_gh_copilot_explain  # bind Alt+shift+\ to explain
      bindkey '^[\' zsh_gh_copilot_suggest  # bind Alt+\ to suggest
      
      bindkey "^[[OH" beginning-of-line
      bindkey "^[[OF" end-of-line
      bind c-left         beginning-of-line
      bind c-right        end-of-line
      bind home           beginning-of-buffer
      bind end            end-of-buffer
      
      bindkey -s ^f "tmux-sessionizer\n"

      # open commands in $EDITOR with C-e
      autoload -z edit-command-line
      zle -N edit-command-line
      bindkey "^e" edit-command-line

      # Completion styling
      # zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
      zstyle ':completion:*' menu no


      # # General completion behavior
      # zstyle ':completion:*' completer _extensions _complete _approximate

      # # Use cache
      # zstyle ':completion:*' use-cache on
      # zstyle ':completion:*' cache-path "$XDG_CACHE_HOME/zsh/.zcompcache"

      # # Complete the alias
      zstyle ':completion:*' complete true

      # # Autocomplete options
      zstyle ':completion:*' complete-options true

      # # Completion matching control
      zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=*' 'l:|=* r:|=*'
      zstyle ':completion:*' keep-prefix true

      # Group matches and describe
      # zstyle ':completion:*' menu select
      zstyle ':completion:*' list-grouped false
      zstyle ':completion:*' list-separator '''
      zstyle ':completion:*' group-name '''
      zstyle ':completion:*' verbose yes
      zstyle ':completion:*:matches' group 'yes'
      zstyle ':completion:*:warnings' format '%F{red}%B-- No match for: %d --%b%f'
      zstyle ':completion:*:messages' format '%d'
      zstyle ':completion:*:corrections' format '%B%d (errors: %e)%b'
      zstyle ':completion:*:descriptions' format '[%d]'

      # # Colors
      # zstyle ':completion:*' list-colors ''${(s.:.)LS_COLORS}

      # Directories
      zstyle ':completion:*:*:cd:*' tag-order local-directories directory-stack path-directories
      zstyle ':completion:*:*:cd:*:directory-stack' menu yes select
      zstyle ':completion:*:-tilde-:*' group-order 'named-directories' 'path-directories' 'users' 'expand'
      zstyle ':completion:*:*:-command-:*:*' group-order aliases builtins functions commands
      zstyle ':completion:*' special-dirs true
      zstyle ':completion:*' squeeze-slashes true

      # Sort
      zstyle ':completion:*' sort false
      zstyle ":completion:*:git-checkout:*" sort false
      zstyle ':completion:*' file-sort modification
      zstyle ':completion:*:eza' sort false
      zstyle ':completion:complete:*:options' sort false
      zstyle ':completion:files' sort false

      # fzf-tab
      zstyle ':fzf-tab:complete:*:*' fzf-preview 'preview $realpath'
      zstyle ':fzf-tab:complete:kill:argument-rest' fzf-preview 'ps --pid=$word -o cmd --no-headers -w -w'
      zstyle ':fzf-tab:complete:kill:argument-rest' fzf-flags '--preview-window=down:3:wrap'
      zstyle ':fzf-tab:*' fzf-command fzf
      zstyle ':fzf-tab:*' fzf-pad 4
      zstyle ':fzf-tab:*' fzf-min-height 100
    '';

    initExtra = ''
      if test -n "$KITTY_INSTALLATION_DIR"; then
          export KITTY_SHELL_INTEGRATION="enabled"
          autoload -Uz -- "$KITTY_INSTALLATION_DIR"/shell-integration/zsh/kitty-integration
          kitty-integration
          unfunction kitty-integration
      fi
      source ~/.openai.sh
      #Python virtualenv
      source ~/.env/bin/activate
      eval "$(atuin init zsh)"
    '';

    envExtra = ''
      export TERM=xterm-256color
    '';

    oh-my-zsh = {
      enable = true;
      plugins = [
        "sudo"
        "1password"
        "adb"
        "azure"
        "aws"
        "direnv"
        "emoji-clock"
        "terraform"
        "starship"
        "git"
        "history"
        "lxd"
      ];
      theme = "gruvbox";
    };

    shellAliases = {
      cp = "cp -rv";
      mkdir = "mkdir -vp";
      mv = "mv -iv";
      top = "btm";
      ls = "eza --header --git --classify --long --binary --group --time-style=long-iso --links --all --all --group-directories-first --sort=name --icons";
      la = "eza --all --icons";
      tree = "eza --all --icons --tree --sort=name";
      cat = "bat --theme=gruvbox-dark";
      cl = "clear";
      mdless = "glow";
      gita = "git add --all";
      gitm = "git commit -m";
      gitp = "git push";
      gitc = "git checkout";
      zellij = "zellij options --default-shell=zsh";
      neofetch = "neofetch --kitty ~/Pictures/wallpapers/Sexy_retro/ --size 300 --crop_mode fill";
      nhu = "nh os switch --update";
      nhs = "nh os switch ";
      today = "curl -s https://wttr.in/London";
      # wttr = "curl -s https://wttr.in/London?0";
      # code = "code --enable-features=UseOzonePlatform --ozone-platform=wayland --disable-gpu";
      dbe = "distrobox enter";
      debian = "distrobox enter debian";
      ask = "chatgpt --model gpt-4 -p";
      # obsidian = "obsidian --enable-features=UseOzonePlatform --ozone-platform=wayland --disable-gpu";
      wezterm = "wezterm start --always-new-process";
      sgrabb = "screenshotin";
    };
  };
}
