# Home Manager Skill

A specialized skill for working with Home Manager in NixOS, providing expert guidance on user environment configuration, dotfile management, and declarative home directory setup.

## Skill Overview

**Purpose**: Provide comprehensive support for Home Manager configuration, module creation, and user environment management.

**Invoke When**:

- Creating or modifying Home Manager configurations
- Setting up user-specific packages and services
- Managing dotfiles declaratively
- Configuring programs with Home Manager modules
- Troubleshooting Home Manager issues
- Migrating from imperative to declarative user configs
- Creating custom Home Manager modules

## Core Capabilities

### 1. Configuration Management

**Home Manager Module Structure**

```nix
{ config, pkgs, ... }:
{
  # Required settings
  home.username = "username";
  home.homeDirectory = "/home/username";
  home.stateVersion = "24.11";  # Set once, never change

  # Package installation
  home.packages = with pkgs; [
    # Packages not managed by programs.*
    ripgrep
    fd
    jq
  ];

  # Program configurations
  programs = { ... };

  # Service management
  services = { ... };

  # File management
  home.file = { ... };

  # Session variables
  home.sessionVariables = { ... };
}
```

**Installation Methods**

**Method 1: NixOS Module (Recommended)**

```nix
# /etc/nixos/configuration.nix
{ config, pkgs, ... }:
{
  imports = [ <home-manager/nixos> ];

  users.users.myuser = {
    isNormalUser = true;
    # ... other user settings
  };

  home-manager.users.myuser = { pkgs, ... }: {
    home.stateVersion = "24.11";
    # User's home-manager configuration
  };

  # Optional: Use user's pkgs
  home-manager.useUserPackages = true;
  # Optional: Use global pkgs
  home-manager.useGlobalPkgs = true;
}
```

**Method 2: Standalone Installation**

```bash
# Add channel
nix-channel --add https://github.com/nix-community/home-manager/archive/release-24.11.tar.gz home-manager
nix-channel --update

# Install
nix-shell '<home-manager>' -A install
```

**Method 3: Flake-based (Modern)**

```nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.11";
    home-manager = {
      url = "github:nix-community/home-manager/release-24.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, ... }: {
    nixosConfigurations.hostname = nixpkgs.lib.nixosSystem {
      modules = [
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.myuser = import ./home.nix;
        }
      ];
    };
  };
}
```

### 2. Program Configuration Patterns

**Shell Configuration (Zsh)**

```nix
programs.zsh = {
  enable = true;

  # Aliases
  shellAliases = {
    ll = "ls -la";
    update = "sudo nixos-rebuild switch";
    hm = "home-manager switch";
  };

  # Oh My Zsh
  oh-my-zsh = {
    enable = true;
    plugins = [ "git" "docker" "kubectl" ];
    theme = "robbyrussell";
  };

  # Additional configuration
  initExtra = ''
    export PATH=$HOME/.local/bin:$PATH

    # Custom functions
    mkcd() {
      mkdir -p "$1" && cd "$1"
    }
  '';

  # Environment variables
  sessionVariables = {
    EDITOR = "vim";
  };

  # History settings
  history = {
    size = 10000;
    path = "${config.xdg.dataHome}/zsh/history";
    ignoreDups = true;
    share = true;
  };
};
```

**Git Configuration**

```nix
programs.git = {
  enable = true;
  userName = "Your Name";
  userEmail = "your.email@example.com";

  # Aliases
  aliases = {
    co = "checkout";
    ci = "commit";
    st = "status";
    br = "branch";
    lg = "log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset'";
  };

  # Extra config
  extraConfig = {
    init.defaultBranch = "main";
    pull.rebase = true;
    push.autoSetupRemote = true;
    core.editor = "vim";

    # Signing
    commit.gpgsign = true;
    user.signingkey = "YOUR_GPG_KEY";
  };

  # Delta (diff viewer)
  delta = {
    enable = true;
    options = {
      navigate = true;
      line-numbers = true;
      syntax-theme = "Dracula";
    };
  };

  # Git LFS
  lfs.enable = true;
};
```

**Neovim/Vim Configuration**

```nix
programs.neovim = {
  enable = true;
  viAlias = true;
  vimAlias = true;
  vimdiffAlias = true;

  # Plugins
  plugins = with pkgs.vimPlugins; [
    vim-nix
    vim-surround
    vim-commentary
    fzf-vim
    lightline-vim
    gruvbox
  ];

  # Extra configuration
  extraConfig = ''
    set number relativenumber
    set tabstop=2 shiftwidth=2 expandtab
    set ignorecase smartcase
    set clipboard=unnamedplus

    colorscheme gruvbox
    set background=dark

    " Leader key
    let mapleader = " "

    " Quick save
    nnoremap <leader>w :w<CR>

    " FZF mappings
    nnoremap <C-p> :Files<CR>
    nnoremap <leader>f :Rg<CR>
  '';

  # Packages available in nvim
  extraPackages = with pkgs; [
    ripgrep
    fd
    nodejs  # For LSP
  ];
};
```

**Terminal Emulator (Alacritty)**

```nix
programs.alacritty = {
  enable = true;

  settings = {
    window = {
      opacity = 0.95;
      padding = {
        x = 10;
        y = 10;
      };
    };

    font = {
      normal = {
        family = "JetBrains Mono";
        style = "Regular";
      };
      size = 12.0;
    };

    colors = {
      primary = {
        background = "#1e1e1e";
        foreground = "#d4d4d4";
      };
      # ... more colors
    };

    keyboard.bindings = [
      { key = "V"; mods = "Control|Shift"; action = "Paste"; }
      { key = "C"; mods = "Control|Shift"; action = "Copy"; }
    ];
  };
};
```

**SSH Configuration**

```nix
programs.ssh = {
  enable = true;

  # SSH config
  matchBlocks = {
    "github.com" = {
      hostname = "github.com";
      user = "git";
      identityFile = "~/.ssh/id_ed25519";
    };

    "work-server" = {
      hostname = "work.example.com";
      user = "workuser";
      port = 2222;
      identityFile = "~/.ssh/work_key";
      forwardAgent = true;
    };

    "home-*" = {
      user = "homeuser";
      identityFile = "~/.ssh/home_key";
    };
  };

  # SSH control master for faster connections
  controlMaster = "auto";
  controlPath = "~/.ssh/master-%r@%n:%p";
  controlPersist = "10m";
};
```

### 3. Service Management

**GPG Agent**

```nix
services.gpg-agent = {
  enable = true;
  defaultCacheTtl = 3600;
  maxCacheTtl = 7200;
  enableSshSupport = true;
  pinentryPackage = pkgs.pinentry-curses;

  # For graphical pinentry
  # pinentryPackage = pkgs.pinentry-gnome3;
};
```

**Syncthing**

```nix
services.syncthing = {
  enable = true;
  tray.enable = true;  # System tray icon
};
```

**Dunst (Notification Daemon)**

```nix
services.dunst = {
  enable = true;
  settings = {
    global = {
      monitor = 0;
      geometry = "300x50-30+20";
      transparency = 10;
      font = "JetBrains Mono 10";
      format = "<b>%s</b>\\n%b";
    };

    urgency_low = {
      background = "#1e1e1e";
      foreground = "#d4d4d4";
      timeout = 5;
    };

    urgency_normal = {
      background = "#1e1e1e";
      foreground = "#d4d4d4";
      timeout = 10;
    };

    urgency_critical = {
      background = "#900000";
      foreground = "#ffffff";
      timeout = 0;
    };
  };
};
```

**Systemd User Services**

```nix
systemd.user.services.my-backup = {
  Unit = {
    Description = "Personal backup service";
  };

  Service = {
    Type = "oneshot";
    ExecStart = "${pkgs.rsync}/bin/rsync -av /home/user/important/ /backup/";
  };
};

systemd.user.timers.my-backup = {
  Unit = {
    Description = "Run backup daily";
  };

  Timer = {
    OnCalendar = "daily";
    Persistent = true;
  };

  Install = {
    WantedBy = [ "timers.target" ];
  };
};
```

### 4. File Management

**Dotfile Management**

```nix
home.file = {
  # Simple file from string
  ".config/myapp/config.yml".text = ''
    setting: value
    another: setting
  '';

  # File from source
  ".config/myapp/theme.conf".source = ./dotfiles/myapp-theme.conf;

  # Executable file
  ".local/bin/my-script" = {
    text = ''
      #!/usr/bin/env bash
      echo "Hello from my script"
    '';
    executable = true;
  };

  # Recursive directory
  ".config/doom" = {
    source = ./doom-config;
    recursive = true;
  };

  # With onChange hook
  ".config/example/config.ini" = {
    text = "config content";
    onChange = ''
      # Restart service when config changes
      systemctl --user restart example.service
    '';
  };
};
```

**XDG Directory Management**

```nix
xdg = {
  enable = true;

  # XDG base directories
  configHome = "${config.home.homeDirectory}/.config";
  dataHome = "${config.home.homeDirectory}/.local/share";
  cacheHome = "${config.home.homeDirectory}/.cache";

  # XDG user directories
  userDirs = {
    enable = true;
    createDirectories = true;
    desktop = "${config.home.homeDirectory}/Desktop";
    documents = "${config.home.homeDirectory}/Documents";
    download = "${config.home.homeDirectory}/Downloads";
    music = "${config.home.homeDirectory}/Music";
    pictures = "${config.home.homeDirectory}/Pictures";
    videos = "${config.home.homeDirectory}/Videos";
  };

  # XDG MIME types
  mimeApps = {
    enable = true;
    defaultApplications = {
      "text/html" = "firefox.desktop";
      "x-scheme-handler/http" = "firefox.desktop";
      "x-scheme-handler/https" = "firefox.desktop";
      "application/pdf" = "org.gnome.Evince.desktop";
    };
  };
};
```

### 5. Desktop Environment Integration

**GTK Theming**

```nix
gtk = {
  enable = true;

  theme = {
    name = "Adwaita-dark";
    package = pkgs.gnome.gnome-themes-extra;
  };

  iconTheme = {
    name = "Papirus-Dark";
    package = pkgs.papirus-icon-theme;
  };

  font = {
    name = "Ubuntu 11";
    package = pkgs.ubuntu_font_family;
  };

  gtk3.extraConfig = {
    gtk-application-prefer-dark-theme = true;
  };

  gtk4.extraConfig = {
    gtk-application-prefer-dark-theme = true;
  };
};
```

**Qt Theming**

```nix
qt = {
  enable = true;
  platformTheme.name = "gtk";
  style.name = "adwaita-dark";
};
```

**Cursor Theme**

```nix
home.pointerCursor = {
  name = "Adwaita";
  package = pkgs.gnome.adwaita-icon-theme;
  size = 24;
  gtk.enable = true;
  x11.enable = true;
};
```

**Font Configuration**

```nix
fonts.fontconfig.enable = true;

home.packages = with pkgs; [
  (nerdfonts.override { fonts = [ "JetBrainsMono" "FiraCode" ]; })
  ubuntu_font_family
  dejavu_fonts
  liberation_ttf
];
```

### 6. Development Environments

**Direnv Integration**

```nix
programs.direnv = {
  enable = true;
  enableZshIntegration = true;
  nix-direnv.enable = true;
};
```

**Language-Specific Tools**

**Node.js/npm**

```nix
home.packages = with pkgs; [
  nodejs_20
  nodePackages.npm
  nodePackages.pnpm
  nodePackages.yarn
];

home.sessionVariables = {
  NPM_CONFIG_PREFIX = "${config.home.homeDirectory}/.npm-global";
};
```

**Python**

```nix
home.packages = with pkgs; [
  python311
  python311Packages.pip
  python311Packages.virtualenv
  poetry
];
```

**Rust**

```nix
home.packages = with pkgs; [
  rustc
  cargo
  rust-analyzer
  rustfmt
  clippy
];

home.sessionVariables = {
  CARGO_HOME = "${config.home.homeDirectory}/.cargo";
  RUSTUP_HOME = "${config.home.homeDirectory}/.rustup";
};
```

### 7. Session Variables and Environment

**Environment Variables**

```nix
home.sessionVariables = {
  EDITOR = "nvim";
  VISUAL = "nvim";
  BROWSER = "firefox";
  TERMINAL = "alacritty";

  # Development
  GOPATH = "${config.home.homeDirectory}/go";
  CARGO_HOME = "${config.home.homeDirectory}/.cargo";

  # XDG compliance
  DOCKER_CONFIG = "${config.xdg.configHome}/docker";
  GRADLE_USER_HOME = "${config.xdg.dataHome}/gradle";

  # Custom paths
  PATH = "$HOME/.local/bin:$PATH";
};

# Shell-specific variables
programs.zsh.sessionVariables = {
  # ZSH-specific vars
  HISTFILE = "${config.xdg.dataHome}/zsh/history";
};
```

**PATH Management**

```nix
home.sessionPath = [
  "${config.home.homeDirectory}/.local/bin"
  "${config.home.homeDirectory}/.cargo/bin"
  "${config.home.homeDirectory}/go/bin"
];
```

### 8. Multi-Machine Configuration

**Shared Configuration Pattern**

```nix
# common.nix - Shared across all machines
{ pkgs, ... }:
{
  home.packages = with pkgs; [
    # Common tools
    vim
    git
    htop
  ];

  programs.git = {
    enable = true;
    userName = "Your Name";
    userEmail = "your.email@example.com";
  };
}
```

```nix
# laptop.nix - Laptop-specific
{ pkgs, ... }:
{
  imports = [ ./common.nix ];

  # Laptop-specific packages
  home.packages = with pkgs; [
    brightnessctl
    acpi
  ];

  # Battery management
  services.auto-cpufreq.enable = true;
}
```

```nix
# desktop.nix - Desktop-specific
{ pkgs, ... }:
{
  imports = [ ./common.nix ];

  # Desktop-specific packages
  home.packages = with pkgs; [
    steam
    obs-studio
  ];

  # Multi-monitor setup
  # ... display configuration
}
```

**Host-Based Configuration**

```nix
{ pkgs, lib, ... }:
let
  hostname = builtins.readFile /etc/hostname;

  isLaptop = hostname == "my-laptop";
  isDesktop = hostname == "my-desktop";
in
{
  imports = [ ./common.nix ]
    ++ lib.optional isLaptop ./laptop.nix
    ++ lib.optional isDesktop ./desktop.nix;
}
```

### 9. Custom Module Creation

**Simple Custom Module**

```nix
# modules/programs/my-tool.nix
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.programs.my-tool;
in
{
  options.programs.my-tool = {
    enable = mkEnableOption "My Tool";

    package = mkOption {
      type = types.package;
      default = pkgs.my-tool;
      description = "The my-tool package to use";
    };

    settings = mkOption {
      type = types.attrs;
      default = {};
      example = {
        option1 = "value1";
        option2 = true;
      };
      description = "Configuration for my-tool";
    };
  };

  config = mkIf cfg.enable {
    home.packages = [ cfg.package ];

    home.file.".config/my-tool/config.toml".text =
      lib.generators.toTOML {} cfg.settings;
  };
}
```

**Usage:**

```nix
{
  imports = [ ./modules/programs/my-tool.nix ];

  programs.my-tool = {
    enable = true;
    settings = {
      theme = "dark";
      font = "monospace";
    };
  };
}
```

### 10. Activation Scripts

**Custom Activation**

```nix
home.activation = {
  # Simple command
  myActivationAction = lib.hm.dag.entryAfter ["writeBoundary"] ''
    run echo "Running custom activation"
    run mkdir -p $HOME/custom-dir
  '';

  # With dependencies
  setupSymlinks = lib.hm.dag.entryAfter ["linkGeneration"] ''
    run ln -sf $HOME/dotfiles/special $HOME/.special
  '';

  # Conditional activation
  conditionalSetup = lib.hm.dag.entryAfter ["writeBoundary"] ''
    if [ ! -f $HOME/.initialized ]; then
      run echo "First-time setup"
      run touch $HOME/.initialized
    fi
  '';
};
```

## Common Patterns and Solutions

### Pattern 1: Secrets Management

**Using sops-nix**

```nix
{
  imports = [ <sops-nix/modules/home-manager> ];

  sops = {
    age.keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
    defaultSopsFile = ./secrets.yaml;

    secrets = {
      github_token = {
        path = "${config.home.homeDirectory}/.github-token";
      };
      aws_credentials = {
        path = "${config.home.homeDirectory}/.aws/credentials";
      };
    };
  };
}
```

**Using agenix**

```nix
{
  imports = [ agenix.homeManagerModules.age ];

  age.secrets.ssh-key = {
    file = ./secrets/ssh-key.age;
    path = "${config.home.homeDirectory}/.ssh/id_ed25519";
    mode = "600";
  };
}
```

### Pattern 2: Conditional Configuration

**Based on hostname**

```nix
{ lib, ... }:
let
  hostname = builtins.readFile /etc/hostname;
in
{
  programs.git.extraConfig = lib.mkIf (hostname == "work-laptop") {
    user.email = "work@company.com";
  };
}
```

**Based on features**

```nix
{ config, lib, ... }:
{
  options.my.features = {
    gaming = lib.mkEnableOption "gaming setup";
    development = lib.mkEnableOption "development tools";
  };

  config = {
    home.packages = with pkgs;
      lib.optionals config.my.features.gaming [
        steam
        discord
      ] ++ lib.optionals config.my.features.development [
        vscode
        docker
      ];
  };
}
```

### Pattern 3: Overlay Integration

```nix
{ pkgs, ... }:
{
  nixpkgs.overlays = [
    (self: super: {
      my-custom-package = super.callPackage ./pkgs/my-package {};
    })
  ];

  home.packages = [ pkgs.my-custom-package ];
}
```

### Pattern 4: Program Override

```nix
programs.neovim = {
  enable = true;
  package = pkgs.neovim-unwrapped.overrideAttrs (oldAttrs: {
    version = "nightly";
    src = pkgs.fetchFromGitHub {
      owner = "neovim";
      repo = "neovim";
      rev = "nightly";
      sha256 = "...";
    };
  });
};
```

## Troubleshooting Guide

### Issue 1: Collision Errors

**Problem**: "Existing file at..." error

**Solution**:

```bash
# Remove conflicting packages installed with nix-env
nix-env --uninstall package-name

# Or remove all
nix-env --uninstall '*'

# Then switch
home-manager switch
```

### Issue 2: Session Variables Not Set

**Problem**: Environment variables not available in new shells

**Solution**:

```nix
# Ensure sourcing in shell config
programs.zsh.initExtra = ''
  if [ -f ~/.nix-profile/etc/profile.d/hm-session-vars.sh ]; then
    . ~/.nix-profile/etc/profile.d/hm-session-vars.sh
  fi
'';
```

### Issue 3: dconf Errors on NixOS

**Problem**: "The name ca.desrt.dconf was not provided by any .service files"

**Solution**:

```nix
programs.dconf.enable = true;

# Or system-wide in NixOS config
programs.dconf.enable = true;
```

### Issue 4: Git Credentials Not Working

**Problem**: Git can't access credentials

**Solution**:

```nix
programs.git = {
  enable = true;
  extraConfig = {
    credential.helper = "store";
    # Or use git-credential-manager
    # credential.helper = "${pkgs.git-credential-manager}/bin/git-credential-manager";
  };
};
```

### Issue 5: Fonts Not Available in Programs

**Problem**: Custom fonts not showing up

**Solution**:

```nix
# Ensure fontconfig is enabled
fonts.fontconfig.enable = true;

# Rebuild font cache
home.activation.rebuildFontCache = lib.hm.dag.entryAfter ["writeBoundary"] ''
  run ${pkgs.fontconfig}/bin/fc-cache -f
'';
```

## Best Practices

### DO ✅

1. **Set stateVersion once and never change it**

   ```nix
   home.stateVersion = "24.11";  # Leave this unchanged
   ```

2. **Use program modules when available**

   ```nix
   # ✅ Good - uses program module
   programs.git.enable = true;

   # ❌ Bad - manual configuration
   home.packages = [ pkgs.git ];
   home.file.".gitconfig".text = "...";
   ```

3. **Import from central configuration**

   ```nix
   imports = [
     ./modules/shell.nix
     ./modules/editor.nix
     ./modules/desktop.nix
   ];
   ```

4. **Use XDG directories**

   ```nix
   xdg.enable = true;
   # Configs go to ~/.config
   # Data goes to ~/.local/share
   ```

5. **Enable rollback capability**

   ```bash
   # Home Manager keeps generations automatically
   home-manager generations
   home-manager switch --rollback
   ```

6. **Version control your configuration**

   ```bash
   cd ~/.config/home-manager
   git init
   git add .
   git commit -m "Initial home-manager config"
   ```

7. **Test changes before committing**

   ```bash
   home-manager switch --dry-run
   home-manager switch
   ```

8. **Use lib functions for conditionals**

   ```nix
   home.packages = lib.optionals stdenv.isLinux [ ... ];
   ```

9. **Document custom modules**

   ```nix
   options.my.feature = mkOption {
     description = "Clear description of what this does";
     # ...
   };
   ```

10. **Use activation scripts for side effects**

    ```nix
    home.activation.setupDirs = lib.hm.dag.entryAfter ["writeBoundary"] ''
      run mkdir -p $HOME/projects
    '';
    ```

### DON'T ❌

1. **Don't change stateVersion casually**

   ```nix
   # ❌ Don't do this
   home.stateVersion = "24.11";  # Changed from 23.11
   ```

2. **Don't mix nix-env and Home Manager**

   ```bash
   # ❌ Don't use nix-env with Home Manager
   nix-env -iA nixpkgs.package

   # ✅ Use home.packages instead
   home.packages = [ pkgs.package ];
   ```

3. **Don't hardcode paths**

   ```nix
   # ❌ Bad
   home.file."/home/user/.config/app/config".text = "...";

   # ✅ Good
   home.file."${config.xdg.configHome}/app/config".text = "...";
   ```

4. **Don't ignore collision errors**

   ```bash
   # ❌ Don't force
   home-manager switch --force

   # ✅ Investigate and fix
   nix-env --query
   nix-env --uninstall conflicting-package
   ```

5. **Don't put secrets in Nix store**

   ```nix
   # ❌ Never do this
   home.file.".ssh/id_rsa".text = "secret key content";

   # ✅ Use secrets management
   sops.secrets.ssh_key.path = "~/.ssh/id_rsa";
   ```

6. **Don't use mutable configuration**

   ```nix
   # ❌ Avoid programs.*.extraConfig when possible
   programs.git.extraConfig = { ... };

   # ✅ Use structured options
   programs.git.aliases = { ... };
   ```

7. **Don't skip documentation**

   ```bash
   # Read options before configuring
   home-manager option search git
   ```

## Command Reference

### Home Manager Commands

```bash
# Apply configuration
home-manager switch

# Build without activating
home-manager build

# Show generations
home-manager generations

# Rollback to previous
home-manager switch --rollback

# Remove old generations
home-manager expire-generations "-7 days"

# Search options
home-manager option search <term>

# Show option details
home-manager option <option-name>

# Help
home-manager --help
```

### NixOS Module Usage

```bash
# Rebuild with home-manager
sudo nixos-rebuild switch

# Test without activating
sudo nixos-rebuild test

# Build without activating
sudo nixos-rebuild build
```

### Generation Management

```bash
# List generations
ls -l ~/.local/state/nix/profiles/home-manager*

# Remove old generations (free space)
nix-collect-garbage --delete-old

# Remove generations older than 30 days
home-manager expire-generations "-30 days"
nix-collect-garbage
```

## Testing Approach

**Incremental Testing**

1. Start with minimal configuration
2. Add one program/service at a time
3. Test after each change
4. Use `--dry-run` flag
5. Keep working generations

**Example Test Workflow**

```bash
# 1. Edit configuration
vim ~/.config/home-manager/home.nix

# 2. Check syntax
nix-instantiate --parse ~/.config/home-manager/home.nix

# 3. Dry run
home-manager switch --dry-run

# 4. Build
home-manager build

# 5. Switch
home-manager switch

# 6. Verify
# Test the changed program/service

# 7. Rollback if needed
home-manager switch --rollback
```

## Advanced Use Cases

### Use Case 1: Development Workstation

Complete setup for software development with multiple languages, tools, and environments.

### Use Case 2: Minimal Server User

Lightweight configuration for server users with just essentials.

### Use Case 3: Desktop Environment

Full desktop setup with GUI applications, theming, and customization.

### Use Case 4: Shared Team Configuration

Base configuration shared across team with host-specific overrides.

## Integration Points

- **With NixOS**: Seamless integration via nixos module
- **With nix-darwin**: macOS support
- **With flakes**: Modern Nix workflow
- **With secrets**: sops-nix, agenix integration
- **With containers**: Per-container user configs

## Success Metrics

- **Configuration**: All dotfiles managed declaratively
- **Reproducibility**: Same config on multiple machines
- **Rollback**: Can revert changes instantly
- **Version Control**: Config tracked in git
- **Documentation**: Options well-documented
- **Testing**: Changes tested before deployment

Ready to work with Home Manager! Let me know what you need help with. 🏠
