# Installer Tools and TUI Utilities for Live USB
{
  pkgs,
  ...
}:
{
  environment.systemPackages = with pkgs; [
    # Text editors
    neovim
    nano
    
    # Terminal utilities
    tmux
    screen
    htop
    btop
    tree
    ranger
    
    # Network tools
    networkmanager
    networkmanagerapplet  # for nmtui
    wget
    curl
    openssh
    tailscale
    
    # Disk and filesystem tools
    parted
    gptfdisk  # gdisk
    util-linux  # fdisk, lsblk, etc.
    dosfstools  # mkfs.fat
    e2fsprogs  # mkfs.ext4
    ntfs3g
    exfatprogs
    cryptsetup
    
    # System tools
    pciutils  # lspci
    usbutils  # lsusb
    dmidecode
    smartmontools
    hdparm
    
    # Development and scripting
    git
    python3
    python3Packages.pyyaml
    jq
    yq
    
    # Archive tools
    unzip
    zip
    tar
    gzip
    
    # File transfer
    rsync
    scp
    
    # System information
    lshw
    hwinfo
    inxi
    
    # Process management
    killall
    psmisc
    procps
    
    # Text processing
    grep
    sed
    awk
    ripgrep
    fd
    
    # Monitoring
    iotop
    iftop
    nethogs
    
    # Terminal enhancements
    bash-completion
    zsh
    oh-my-zsh
    
    # File managers
    mc  # Midnight Commander
    
    # Network diagnostics
    inetutils  # ping, telnet, etc.
    dnsutils   # dig, nslookup
    tcpdump
    nmap
    
    # Hardware testing
    memtest86plus
    stress
    stress-ng
  ];

  # Configure neovim with basic settings
  environment.etc."nvim/init.vim".text = ''
    " Basic neovim configuration for installer
    set number
    set relativenumber
    set tabstop=2
    set shiftwidth=2
    set expandtab
    set autoindent
    set smartindent
    set hlsearch
    set incsearch
    set ignorecase
    set smartcase
    set wrap
    set linebreak
    set mouse=a
    set clipboard=unnamedplus
    
    " Syntax highlighting
    syntax on
    filetype plugin indent on
    
    " Color scheme
    colorscheme default
    
    " Key mappings
    nnoremap <C-s> :w<CR>
    inoremap <C-s> <Esc>:w<CR>a
    nnoremap <C-q> :q<CR>
    nnoremap <C-x> :wq<CR>
  '';

  # Configure tmux
  environment.etc."tmux.conf".text = ''
    # Basic tmux configuration for installer
    set -g default-terminal "screen-256color"
    set -g mouse on
    set -g history-limit 10000
    
    # Key bindings
    bind r source-file /etc/tmux.conf \; display-message "Config reloaded!"
    bind | split-window -h
    bind - split-window -v
    
    # Status bar
    set -g status-bg blue
    set -g status-fg white
    set -g status-left '[#S] '
    set -g status-right '%Y-%m-%d %H:%M'
    
    # Pane border colors
    set -g pane-border-style fg=blue
    set -g pane-active-border-style fg=red
  '';

  # Configure bash with useful aliases
  environment.etc."bashrc.local".text = ''
    # Installer-specific bash configuration
    
    # Aliases
    alias ll='ls -alF'
    alias la='ls -A'
    alias l='ls -CF'
    alias ..='cd ..'
    alias ...='cd ../..'
    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
    
    # Disk utilities
    alias lsblk='lsblk -f'
    alias mount='mount | column -t'
    alias df='df -h'
    alias du='du -h'
    
    # Network utilities
    alias ports='netstat -tulanp'
    alias myip='curl -s ipinfo.io/ip'
    alias ping='ping -c 5'
    
    # System information
    alias meminfo='free -m -l -t'
    alias cpuinfo='lscpu'
    alias diskinfo='fdisk -l'
    
    # Process management
    alias psg='ps aux | grep -v grep | grep -i -E'
    alias psmem='ps auxf | sort -nr -k 4'
    alias pscpu='ps auxf | sort -nr -k 3'
    
    # Quick navigation to installer files
    alias cdconfig='cd /etc/nixos-config'
    alias cdscripts='cd /etc/nixos-config/scripts/install-helpers'
    
    # Installation helpers
    alias show-disks='lsblk -f && echo && fdisk -l'
    alias show-partitions='cat /proc/partitions && echo && lsblk'
    alias show-mounts='mount | grep -E "^/dev"'
    
    # Set a nice prompt
    export PS1='\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
    
    # Enable bash completion
    if [ -f /etc/profile.d/bash_completion.sh ]; then
      source /etc/profile.d/bash_completion.sh
    fi
    
    # Welcome message function
    installer_help() {
      echo "NixOS Live Installer Help:"
      echo "========================="
      echo "show-disks      - Display all disks and partitions"
      echo "show-partitions - Show partition table"
      echo "show-mounts     - Show currently mounted filesystems"
      echo "cdconfig        - Go to configuration directory"
      echo "cdscripts       - Go to installation scripts"
      echo ""
      echo "To start installation:"
      echo "sudo /etc/nixos-config/scripts/install-helpers/install-wizard.sh <hostname>"
      echo ""
      echo "Available hosts: p620, razer, p510, dex5550, samsung"
    }
    
    # Show help on login
    if [ "$PS1" ]; then
      installer_help
    fi
  '';

  # Source the custom bashrc
  environment.etc."bash.bashrc".text = ''
    # System-wide bashrc
    if [ -f /etc/bashrc.local ]; then
      source /etc/bashrc.local
    fi
  '';

  # Configure shell environment
  environment.variables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
    PAGER = "less";
    LESS = "-R";
  };

  # Enable bash completion
  programs.bash = {
    enableCompletion = true;
    interactiveShellInit = ''
      if [ -f /etc/bashrc.local ]; then
        source /etc/bashrc.local
      fi
    '';
  };

  # Configure less for better viewing
  environment.etc."lesskey".text = ''
    #command
    q quit
    :q quit
    Q quit
    ZZ quit
  '';
}