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
    #---------------------------------------------------------------------
        # Nixos related
        #---------------------------------------------------------------------
        
        # rbs2 =      "sudo nixos-rebuild switch -I nixos-config=$HOME/nixos/configuration.nix";
        garbage =     "sudo nix-collect-garbage --delete-older-than 2d";
        lgens =       "sudo nix-env --profile /nix/var/nix/profiles/system --list-generations";
        neu =         "sudo nix-env --upgrade";
        nopt =        "sudo nix-store --optimise";
        rbs =         "sudo nixos-rebuild switch";
        rebuild-all = "sudo nix-collect-garbage --delete-old && sudo nix-collect-garbage -d && sudo /run/current-system/bin/switch-to-configuration boot && sudo fstrim -av";
        switch =      "sudo nixos-rebuild switch -I nixos-config=$HOME/nixos/configuration.nix";
                
        #---------------------------------------------------------------------
        # Navigate files and directories
        #---------------------------------------------------------------------
        
        # cd = "cd ..";
        CL =    "source ~/.bashrc";
        cl =    "clear && CL";
        cong =  "echo && sysctl net.ipv4.tcp_congestion_control && echo";
        copy =  "rsync -P";
        io =    "echo &&  cat /sys/block/sda/queue/scheduler && echo";
        trim =  "sudo fstrim -av";

        #---------------------------------------------------------------------
        # Fun stuff
        #---------------------------------------------------------------------

        icons = "sxiv -t $HOME/Pictures/icons";
        wp = "sxiv -t $HOME/Pictures/Wallpapers";

        #---------------------------------------------------------------------
        # File access
        #---------------------------------------------------------------------
        mkdir = "mkdir -vp";
        mv = "mv -iv";
        cp = "cp -riv";
        #---------------------------------------------------------------------
        # Div
        #---------------------------------------------------------------------
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
        #---------------------------------------------------------------------
        # R3 stuff
        #---------------------------------------------------------------------
        cbuae-uat = "export HTTPS_PROXY=http://localhost:55556 KUBECONFIG=$HOME/.kube/kubeconfig_uat";
        cbuae-dev = "export HTTPS_PROXY=http://localhost:55556 KUBECONFIG=$HOME/.kube/kubeconfig_dev";
        cbuae-prod = "export HTTPS_PROXY=http://localhost:55556 KUBECONFIG=$HOME/.kube/kubeconfig_prod";
      };
};





}
