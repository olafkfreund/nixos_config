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


programs.bash = {
  enable = true;
  enableCompletion = true;
  # TODO add your cusotm bashrc here
  bashrcExtra = ''
   	export PATH="$PATH:$HOME/bin:$HOME/.local/bin:$HOME/go/bin"
    export OPENAI_API_KEY=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
    export OPENAI_KEY=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
    export PATH="$PATH:/home/olafkfreund/.spicetify"
    export PATH="$PATH:/home/olafkfreund/.cargo/bin"
    export PATH="$PATH:/home/olafkfreund/go/bin"
    export IN_API_KEY=90e5bc5705184498af1de989c7beac7e
    export PATH="$HOME/.config/rofi/scripts:$PATH"
    export PATH="$HOME/.npm-global/bin:$PATH"
    export TERM=xterm
  '';

# set some aliases, feel free to add more or remove some
  shellAliases = {
    cp = "cp -riv";
    mkdir = "mkdir -vp";
    mv = "mv -iv";
	  top = "btm";
	  vim = "lvim";
	  ls = "eza --header --git --classify --long --binary --group --time-style=long-iso --links --all --all --group-directories-first --sort=name --icons";
		cat = "bat --theme=gruvbox-dark";
	  mdless = "glow";
	  gita = "git add --all";
	  gitm = "git commit -m";
	  gitp = "git push";
	  gitc = "git checkout";
	  icat = "kitty +kitten icat";
	  dbe = "distrobox enter";
	  gcal = "gcalcli --client-id=333593472146-2ptqh0oqbc82jvrda1idu1qu5v70lmsi.apps.googleusercontent.com --client-secret=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 calm";
	  ask = "chatgpt --model gpt-4 -p";
	  obsidian = "obsidian --enable-features=UseOzonePlatform --ozone-platform=wayland --disable-gpu";
	  cbuae-uat = "export HTTPS_PROXY=http://localhost:55556 KUBECONFIG=$HOME/.kube/kubeconfig_uat";
	  cbuae-dev = "export HTTPS_PROXY=http://localhost:55556 KUBECONFIG=$HOME/.kube/kubeconfig_dev";
	  cbuae-prod = "export HTTPS_PROXY=http://localhost:55556 KUBECONFIG=$HOME/.kube/kubeconfig_prod";
  };
};





}
