{
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    xdg-utils # provides cli tools such as `xdg-mime` `xdg-open`
    xdg-user-dirs
    bashInteractive
    bash-completion
  ];

programs.zoxide.enableBashIntegration = true;

programs.bash = {
  enable = true;
  enableCompletion = true;
  bashrcExtra = ''
   	export PATH="$PATH:$HOME/bin:$HOME/.local/bin:$HOME/go/bin"
    # export OPENAI_API_KEY=
    # export OPENAI_KEY=
    export PATH="$PATH:/home/olafkfreund/.spicetify"
    export PATH="$PATH:/home/olafkfreund/.cargo/bin"
    export PATH="$PATH:/home/olafkfreund/go/bin"
    export PATH="$HOME/.config/rofi/scripts:$PATH"
    export PATH="$HOME/.npm-global/bin:$PATH"
    export TERM=xterm
    export EDITOR=lvim
    export VISUAL=lvim
    source $HOME/.openai.sh
    eval "$(direnv hook bash)"
    eval "$(starship init bash)"
    eval "$(atuin init bash)"
    #export DOCKER_HOST=unix:///run/user/$UID/podman/podman.sock
  '';

# set some aliases, feel free to add more or remove some
  shellAliases = {
    cp = "cp -rv";
    mkdir = "mkdir -vp";
    mv = "mv -iv";
	  top = "btm";
	  vim = "lvim";
	  ls = "eza --header --git --classify --long --binary --group --time-style=long-iso --links --all --all --group-directories-first --sort=name --icons";
	  la = "eza --all --icons";
		cat = "bat --theme=gruvbox-dark";
	  mdless = "glow";
	  gita = "git add --all";
	  gitm = "git commit -m";
	  gitp = "git push";
	  gitc = "git checkout";
	  icat = "kitty +kitten icat";
    neofetch = "neofetch --iterm2 ~/Pictures/1_d2RiMW4zoHLUK-751E38gQ.png --size 200";
    nri = "sudo nixos-rebuild switch --impure|& nom";
    nr = "sudo nixos-rebuild switch|& nom";
    today = "curl -s https://wttr.in/London?1";
    wttr = "curl -s https://wttr.in/London?0";
    fu = "sudo nix flake update|& nom";
    code = "code --enable-features=UseOzonePlatform --ozone-platform=wayland --disable-gpu";
	  dbe = "distrobox enter";
	  ask = "chatgpt --model gpt-4 -p";
	  obsidian = "obsidian --enable-features=UseOzonePlatform --ozone-platform=wayland --disable-gpu";
    google-chrome-stable = "google-chrome-stable --ozone-platform=wayland";
    microsoft-edge-stable = "microsoft-edge-stable --ozone-platform=wayland";
    #Work only
    slack = "slack --ozone-platform=wayland --enable-features=UseOzonePlatform,WebRTCPipeWireCapturer";
    ow = "zellij --layout ~/.config/zellij/layouts/work.kdl";
    cbuae-login = "chromium --proxy-server=socks5://localhost:55553";
	  cbuae-uat = "export HTTPS_PROXY=http://localhost:55556 KUBECONFIG=$HOME/.kube/cbuae-mvp-uat-cce-cluster";
	  cbuae-dev = "export HTTPS_PROXY=http://localhost:55556 KUBECONFIG=$HOME/.kube/cbuae-mvp-dev-cce-cluster";
	  cbuae-prod = "export HTTPS_PROXY=http://localhost:55556 KUBECONFIG=$HOME/.kube/cbuae-mvp-prod-cce-cluster";
  };
};





}
