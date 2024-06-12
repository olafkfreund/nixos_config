{ pkgs, ... }: {
  home.packages = with pkgs; [
    zsh
    oh-my-zsh
    zplug
    zsh-edit
    zsh-fzf-tab
    zsh-f-sy-h
    zsh-nix-shell
    zsh-autopair
    zsh-edit
    zsh-clipboard
    zsh-autocomplete
    zsh-syntax-highlighting
    nix-zsh-completions
    zsh-autosuggestions
    any-nix-shell
  ];

programs.zsh = {
  enable = true; 
  enableCompletion = true;
  syntaxHighlighting.enable = true;
  autosuggestion.enable = true;
  
  initExtra = ''
    source ${pkgs.zsh-fzf-tab}/share/fzf-tab/fzf-tab.plugin.zsh
    source ${pkgs.zsh-autocomplete}/share/zsh-autocomplete/zsh-autocomplete.plugin.zsh
    source ${pkgs.zsh-nix-shell}/share/zsh-nix-shell/nix-shell.plugin.zsh
    source ${pkgs.zsh-f-sy-h}/share/zsh/site-functions/F-Sy-H.plugin.zsh
    source ${pkgs.zsh-syntax-highlighting}/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
    source ${pkgs.nix-zsh-completions}/share/zsh/plugins/nix/nix-zsh-completions.plugin.zsh
    # Completion styling
    zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
    zstyle ':completion:*' list-colors "''${(s.:.)LS_COLORS}"
    zstyle ':completion:*' menu no
    zstyle ':fzf-tab:complete:cd:*' fzf-preview 'ls --color $realpath'
    zstyle ':fzf-tab:complete:__zoxide_z:*' fzf-preview 'ls --color $realpath'
    source ~/.openai.sh
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

      ];
    theme = "gruvbox";
  };

  shellAliases = {
    cp = "cp -rv";
    mkdir = "mkdir -vp";
    mv = "mv -iv";
	  top = "btm";
	  vim = "lvim";
	  nvim = "lvim";
	  ls = "eza --header --git --classify --long --binary --group --time-style=long-iso --links --all --all --group-directories-first --sort=name --icons";
	  la = "eza --all --icons";
		cat = "bat --theme=gruvbox-dark";
	  mdless = "glow";
	  gita = "git add --all";
	  gitm = "git commit -m";
	  gitp = "git push";
	  gitc = "git checkout";
    zellij = "zellij options --default-shell=zsh";
    neofetch = "neofetch --kitty ~/Pictures/PXL_20221014_102401611.PORTRAIT~3.jpg --size 200";
    nri = "sudo nixos-rebuild switch --impure|& nom";
    nr = "sudo nixos-rebuild switch|& nom";
    today = "curl -s https://wttr.in/London?1";
    wttr = "curl -s https://wttr.in/London?0";
    fu = "sudo nix flake update";
    code = "code --enable-features=UseOzonePlatform --ozone-platform=wayland --disable-gpu";
	  dbe = "distrobox enter";
	  debian = "distrobox enter debian";
	  ask = "chatgpt --model gpt-4 -p";
	  obsidian = "obsidian --enable-features=UseOzonePlatform --ozone-platform=wayland --disable-gpu";
    google-chrome-stable = "google-chrome-stable --ozone-platform=wayland";
    microsoft-edge-stable = "microsoft-edge-stable --ozone-platform=wayland";
    # slack = "slack --ozone-platform=wayland --enable-features=UseOzonePlatform,WebRTCPipeWireCapturer";
    };
  };











}
