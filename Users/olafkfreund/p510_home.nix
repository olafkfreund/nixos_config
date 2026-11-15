# P510 is a desktop and media server; state its Home Manager choices directly.
{ lib, pkgs, ... }: {
  imports = [
    ../common/default.nix
    ./private.nix
    {
      imports = [
        ../../home/browsers/default.nix
        ../../home/desktop/terminals/default.nix
        ../../home/shell/default.nix
        ../../home/development/default.nix
        ../../home/media/music.nix
        ../../home/files.nix
        ../../home/desktop/zathura/default.nix
        ../../home/desktop/obsidian/default.nix
        ../../home/desktop/flameshot/default.nix
        ../../home/desktop/omareel/default.nix
        ../../home/desktop/remotedesktop/default.nix
        ../../home/desktop/evince/default.nix
        ../../home/desktop/kdeconnect/default.nix
        ../../home/desktop/slack/default.nix
      ];
    }
  ];

  features = {
    editors = {
      enable = true;
      neovim = true;
    };
    development = {
      enable = true;
      languages = true;
      workflow = true;
      productivity = true;
    };
    cli = {
      enable = true;
      bat = true;
      direnv = true;
      fzf = true;
      lf = true;
      starship = true;
      yazi = true;
      zoxide = true;
      gh = true;
      markdown = true;
    };
    multiplexers = {
      enable = true;
      tmux = true;
    };
  };

  ghostty.enable = true;
  foot.enable = true;
  kitty.enable = true;
  alacritty.enable = true;

  home.packages = with pkgs; [
    # Server development essentials
    # docker, docker-compose, kubectl, k9s: installed system-wide.
    # Re-declaring at user level produces buildEnv collisions.

    # Intel Xeon + NVIDIA specific tools
    intel-gpu-tools
    python3Packages.pynvml
    # nvtopPackages.nvidia - removed to avoid conflict with neofetch module's nvtopPackages.full

    # Media server development (P510 hosts media services)
    ffmpeg
    imagemagick

    # Database tools for development
    postgresql
    redis

    # Network development and monitoring
    netcat
    socat
    nmap
    tcpdump

    # Performance analysis for server optimization
    htop
    btop
    iotop

    # File operations
    sd
    tree

    # System analysis
    lsof
    strace

    # API development and testing
    httpie

    # Text processing
    gnused
    gawk

    # Process management
    psmisc
    procps

    # Disk and storage tools
    ncdu
    rsync

    # Developer and server-admin packages formerly supplied by profiles.
    git-lfs
    delta
    difftastic
    nodejs_24
    python3
    rustc
    postman
    insomnia
    xmlstarlet
    pandoc
    graphviz
    buildah
    terraform
    ansible
    dig
    whois
  ];

  programs.git = {
    enable = true;
    settings = {
      init.defaultBranch = "main";
      push.autoSetupRemote = true;
      pull.rebase = true;
      rebase.autoStash = true;
      core.autocrlf = "input";
      merge.tool = "vimdiff";
      status.showUntrackedFiles = "all";
    };
  };

  programs.delta = {
    enable = lib.mkForce true;
    enableGitIntegration = true;
  };
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
  programs.claude-powerline.enable = true;
  programs.splashboard.enable = true;
  programs.gogDashboard = {
    enable = true;
    account = "olaf@freundcloud.com";
  };
}
