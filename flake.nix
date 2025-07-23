{
  description = "Olaf's flake with Home Manager enabled";

  nixConfig = {
    # Primary caches
    substituters = [
      "https://cache.nixos.org/"
      "https://nix-community.cachix.org"
      #"http://192.168.1.97:5000"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "p620-nix-serve:mZR6o5z5KcWeu4PVXgjHA7vb1sHQgRdWMKQt8x3a4rU="
    ];

    # Development and specific package caches
    extra-substituters = [
      "https://cuda-maintainers.cachix.org"
      "https://hyprland.cachix.org"
      "https://devenv.cachix.org"
      "https://cosmic.cachix.org/"
      "https://cache.saumon.network/proxmox-nixos"
      "https://walker-git.cachix.org"
      "https://walker.cachix.org"
      "http://192.168.1.97:5000"
    ];
    extra-trusted-public-keys = [
      "cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E="
      "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
      "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw="
      "cosmic.cachix.org-1:Dya9IyXD4xdBehWjrkPv6rtxpmMdRel02smYzA85dPE="
      "walker-git.cachix.org-1:vmC0ocfPWh0S/vRAQGtChuiZBTAe4wiKDeyyXM0/7pM="
      "walker.cachix.org-1:fG8q+uAaMqhsMxWjwvk0IMb4mFPFLqHjuvfwQxE4oJM="
      "p620-nix-serve:mZR6o5z5KcWeu4PVXgjHA7vb1sHQgRdWMKQt8x3a4rU="
    ];
  };

  inputs = {
    # Core
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-25.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    flake-utils.url = "github:numtide/flake-utils";

    # Environment and theming
    home-manager.url = "github:nix-community/home-manager";
    nix-colors.url = "github:misterio77/nix-colors";
    stylix.url = "github:danth/stylix";

    # Editor
    nixvim = {
      url = "github:nix-community/nixvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Development and utilities
    sops-nix = {
      url = "github:mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Applications and specific tools
    claude-desktop = {
      url = "github:k3d3/claude-desktop-linux-flake";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
    };

    # Desktop environment
    hyprland = {
      url = "github:hyprwm/Hyprland";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Browser and media
    spicetify-nix.url = "github:Gerg-L/spicetify-nix";

    # System utilities
    agenix.url = "github:ryantm/agenix";
    nix-snapd.url = "github:io12/nix-snapd";
    microvm.url = "github:astro/microvm.nix";

    # Additional tools
    lan-mouse.url = "github:feschber/lan-mouse";
    bzmenu.url = "github:e-tho/bzmenu";
    iwmenu.url = "github:e-tho/iwmenu";
    walker.url = "github:abenz1267/walker";
    zjstatus.url = "github:dj95/zjstatus";
    ags.url = "github:Aylur/ags";

    # Hardware specific
    razer-laptop-control.url = "github:Razer-Linux/razer-laptop-control-no-dkms";

    # Package collections
    nur.url = "github:nix-community/NUR";
    nixpkgs-f2k.url = "github:moni-dz/nixpkgs-f2k";
    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixai.url = "github:olafkfreund/nix-ai-help";
  };

  outputs = {
    self,
    nixpkgs,
    nixpkgs-stable,
    nixpkgs-unstable,
    nur,
    nixai,
    agenix,
    razer-laptop-control,
    nixpkgs-f2k,
    nix-colors,
    ags,
    nix-snapd,
    spicetify-nix,
    home-manager,
    stylix,
    nix-index-database,
    bzmenu,
    iwmenu,
    zjstatus,
    walker,
    hyprland,
    nixvim,
    ...
  } @ inputs: let
    # Define users per host
    hostUsers = {
      p620 = ["olafkfreund"];
      samsung = ["olafkfreund"];
      razer = ["olafkfreund"];
      p510 = ["olafkfreund"];
      dex5550 = ["olafkfreund"];
    };

    # Live USB installer images for each host
    mkLiveImage = hostName: let
      hostConfig = hostUsers.${hostName} or ["olafkfreund"];
    in
      nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = {
          inherit inputs;
          host = hostName;
          hostUsers = hostConfig;
        };
        modules = [
          # Import live system configuration
          ({
            config,
            lib,
            pkgs,
            modulesPath,
            ...
          }: {
            imports = [
              "${modulesPath}/installer/cd-dvd/installation-cd-minimal.nix"
            ];

            # Basic system configuration
            time.timeZone = lib.mkDefault "Europe/Oslo";
            i18n.defaultLocale = lib.mkDefault "en_GB.UTF-8";

            # Network configuration
            networking = {
              hostName = lib.mkDefault "nixos-installer";
              networkmanager.enable = true;
              wireless.enable = false;
              firewall = {
                enable = true;
                allowedTCPPorts = [22];
              };
            };

            # SSH configuration for remote installation
            services.openssh = {
              enable = true;
              settings = {
                PermitRootLogin = "yes";
                PasswordAuthentication = true;
                KbdInteractiveAuthentication = false;
              };
            };

            # Set root password for SSH access
            users.users.root.password = "nixos";

            # Copy flake configuration to live system
            environment.etc."nixos-config" = {
              source = ./.;
              target = "nixos-config";
            };

            # ISO configuration
            isoImage = {
              isoName = lib.mkDefault "nixos-${hostName}-live.iso";
              volumeID = lib.mkDefault "NIXOS_${lib.toUpper hostName}";
              makeEfiBootable = true;
              makeUsbBootable = true;
              squashfsCompression = "gzip -Xcompression-level 1";
            };

            # Boot configuration
            boot = {
              supportedFilesystems = ["ext4" "vfat" "ntfs" "exfat"];
              kernelParams = ["boot.shell_on_fail"];
              initrd.availableKernelModules = [
                "xhci_pci"
                "ehci_pci"
                "ahci"
                "usb_storage"
                "sd_mod"
                "nvme"
                "sdhci_pci"
                "rtsx_pci_sdmmc"
              ];
            };

            # System configuration
            nixpkgs.config = {
              allowUnfree = true;
              allowInsecure = true;
            };

            # Enable flakes
            nix.settings = {
              experimental-features = ["nix-command" "flakes"];
              substituters = [
                "https://cache.nixos.org/"
                "https://nix-community.cachix.org"
              ];
              trusted-public-keys = [
                "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
                "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
              ];
            };

            # No GUI services
            services.xserver.enable = false;

            # Welcome message
            environment.etc."issue".text = ''
              Welcome to NixOS Live Installer for ${hostName}

              To install: sudo install-${hostName}
              For SSH: root/nixos (CHANGE AFTER INSTALL!)
              Config: /etc/nixos-config
            '';

            # Bash configuration with helpful aliases
            programs.bash = {
              interactiveShellInit = ''
                # Helpful aliases for installation
                alias ll='ls -la'
                alias la='ls -A'
                alias l='ls -CF'
                alias ..='cd ..'
                alias ...='cd ../..'
                alias grep='grep --color=auto'
                alias fgrep='fgrep --color=auto'
                alias egrep='egrep --color=auto'

                # NixOS specific aliases
                alias nix-repl='nix repl'
                alias nixos-help='man configuration.nix'
                alias show-config='cat /etc/nixos-config/hosts/${hostName}/configuration.nix'
                alias show-hardware='cat /etc/nixos-config/hosts/${hostName}/hardware-configuration.nix'
                alias list-devices='lsblk -f'
                alias scan-hardware='lshw -short'

                # Installation helpers
                alias start-install='sudo install-${hostName}'
                alias test-config='test-${hostName}-config'
                alias quick-install='echo "Quick install for ${hostName}"; sudo install-${hostName} --quick'

                # Set a nice prompt
                export PS1='\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '

                # Show welcome message on login
                echo ""
                echo "🚀 NixOS Live Installer for ${hostName}"
                echo "📝 Quick commands:"
                echo "   start-install    - Begin installation wizard"
                echo "   test-config      - Test hardware configuration"
                echo "   list-devices     - Show available disks"
                echo "   scan-hardware    - Show hardware overview"
                echo "   show-config      - View host configuration"
                echo ""
              '';
            };
          })

          # Host-specific configuration
          {
            _module.args.host = hostName;

            # Override default nixpkgs config
            nixpkgs.config = {
              allowUnfree = true;
              allowInsecure = true;
            };

            # Comprehensive TUI tools and installer packages
            environment.systemPackages = with nixpkgs.legacyPackages.x86_64-linux; [
              # Host-specific installer commands
              (writeScriptBin "install-${hostName}" ''
                #!/bin/bash
                exec /etc/nixos-config/scripts/install-helpers/install-wizard.sh "${hostName}" "$@"
              '')

              (writeScriptBin "test-${hostName}-config" ''
                #!/bin/bash
                echo "Testing hardware configuration for ${hostName}..."
                /etc/nixos-config/scripts/install-helpers/parse-hardware-config.py "${hostName}"
              '')

              # Essential TUI tools
              neovim
              nano
              tmux
              htop
              btop
              tree
              ranger

              # System information and hardware detection
              lshw
              hwinfo
              pciutils
              usbutils
              dmidecode
              inxi
              smartmontools

              # Disk partitioning and filesystem tools
              parted
              gptfdisk
              util-linux
              dosfstools
              e2fsprogs
              ntfs3g
              exfatprogs
              btrfs-progs
              xfsprogs

              # Network tools
              networkmanager
              curl
              wget
              nettools
              iproute2
              iperf3
              tcpdump
              nmap
              openssh

              # Archive and file tools
              unzip
              zip
              gnutar
              gzip
              p7zip
              file
              which
              rsync
              rclone

              # Development and system tools
              git
              python3
              python3Packages.pyyaml
              python3Packages.requests
              jq
              bc
              coreutils
              findutils
              gnugrep
              gnused
              gawk

              # Text processing
              less
              more
              vim
              diffutils
              patch

              # System monitoring
              iotop
              nethogs
              powertop
              lsof
              psmisc

              # Boot and rescue tools
              testdisk
              ddrescue

              # Console enhancements
              bash-completion
              zsh
              oh-my-zsh

              # Terminal multiplexer and session management
              screen
              zellij
            ];
          }
        ];
      };

    liveImages = {
      p620 = mkLiveImage "p620";
      razer = mkLiveImage "razer";
      p510 = mkLiveImage "p510";
      dex5550 = mkLiveImage "dex5550";
      samsung = mkLiveImage "samsung";
    };

    # MicroVM configurations
    mkMicroVM = vmName: vmConfig:
      nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = {
          inherit inputs;
        };
        modules = [
          inputs.microvm.nixosModules.microvm
          {
            networking.hostName = vmName;

            # Basic system configuration
            time.timeZone = "Europe/Oslo";
            i18n.defaultLocale = "en_GB.UTF-8";
            system.stateVersion = "25.11";

            # Enable flakes
            nix.settings.experimental-features = ["nix-command" "flakes"];

            # Allow unfree packages
            nixpkgs.config.allowUnfree = true;

            # MicroVM configuration
            microvm = {
              hypervisor = "qemu";

              # Resource allocation
              mem = 8192; # 8GB RAM
              vcpu = 4; # 4 CPU cores

              # Network configuration - Simple NAT
              interfaces = [
                {
                  type = "user";
                  id = "vm-user";
                  mac = vmConfig.mac or "02:00:00:01:01:01";
                }
              ];

              # Port forwarding for SSH and development
              forwardPorts =
                vmConfig.forwardPorts or [
                  {
                    from = "host";
                    host.port = vmConfig.sshPort or 2222;
                    guest.port = 22;
                  }
                ];

              # Storage configuration
              shares =
                [
                  {
                    # Shared /nix/store for efficiency
                    source = "/nix/store";
                    mountPoint = "/nix/.ro-store";
                    tag = "ro-store";
                    proto = "virtiofs";
                    socket = "store.sock";
                  }
                  {
                    # Shared host directory
                    source = "/tmp/microvm-shared";
                    mountPoint = "/mnt/shared";
                    tag = "shared";
                    proto = "virtiofs";
                    socket = "shared.sock";
                  }
                ]
                ++ (vmConfig.extraShares or []);

              # Persistent volumes
              volumes = vmConfig.volumes or [];
            };
          }
          vmConfig.extraModules or {}
        ];
      };

    microvms = {
      dev-vm = mkMicroVM "dev-vm" {
        mac = "02:00:00:01:01:01";
        sshPort = 2222;
        forwardPorts = [
          {
            from = "host";
            host.port = 2222;
            guest.port = 22;
          }
          {
            from = "host";
            host.port = 8080;
            guest.port = 80;
          }
          {
            from = "host";
            host.port = 3000;
            guest.port = 3000;
          }
        ];
        extraShares = [
          {
            source = "/var/lib/microvms/dev-vm/projects";
            mountPoint = "/home/dev/projects";
            tag = "projects";
            proto = "virtiofs";
            socket = "projects.sock";
          }
        ];
        volumes = [
          {
            image = "/var/lib/microvms/dev-vm/home.img";
            mountPoint = "/home/dev";
            size = 10240; # 10GB
          }
        ];
        extraModules = {
          # Development environment packages
          environment.systemPackages = with nixpkgs.legacyPackages.x86_64-linux; [
            git
            vim
            neovim
            tmux
            htop
            tree
            curl
            wget
            nodejs
            python3
            go
            rustc
            docker-compose
            gcc
            gnumake
            cmake
            ninja
          ];

          # Create dev user
          users.users.dev = {
            isNormalUser = true;
            password = "dev";
            extraGroups = ["wheel" "docker"];
            shell = nixpkgs.legacyPackages.x86_64-linux.bash;
          };

          # Enable SSH
          services.openssh = {
            enable = true;
            settings.PasswordAuthentication = true;
          };

          # Enable Docker
          virtualisation.docker.enable = true;
        };
      };

      test-vm = mkMicroVM "test-vm" {
        mac = "02:00:00:01:01:02";
        sshPort = 2223;
        extraShares = [
          {
            source = "/var/lib/microvms/test-vm/data";
            mountPoint = "/mnt/data";
            tag = "data";
            proto = "virtiofs";
            socket = "data.sock";
          }
        ];
        extraModules = {
          # Minimal testing environment
          environment.systemPackages = with nixpkgs.legacyPackages.x86_64-linux; [
            git
            vim
            htop
            tree
            curl
            wget
            python3
          ];

          # Create test user
          users.users.test = {
            isNormalUser = true;
            password = "test";
            extraGroups = ["wheel"];
          };

          # Enable SSH
          services.openssh = {
            enable = true;
            settings.PasswordAuthentication = true;
          };
        };
      };

      playground-vm = mkMicroVM "playground-vm" {
        mac = "02:00:00:01:01:03";
        sshPort = 2224;
        forwardPorts = [
          {
            from = "host";
            host.port = 2224;
            guest.port = 22;
          }
          {
            from = "host";
            host.port = 8081;
            guest.port = 80;
          }
        ];
        extraShares = [
          {
            source = "/var/lib/microvms/playground-vm/experiments";
            mountPoint = "/root/experiments";
            tag = "experiments";
            proto = "virtiofs";
            socket = "experiments.sock";
          }
        ];
        extraModules = {
          # Allow unfree packages for experimental tools
          nixpkgs.config.allowUnfree = true;

          # Experimental playground packages
          environment.systemPackages = with nixpkgs.legacyPackages.x86_64-linux; [
            git
            vim
            neovim
            tmux
            htop
            tree
            curl
            wget
            python3
            nodejs
            go
            rustc
            docker-compose
            kubernetes
            helm
            ansible
            wireshark
            tcpdump
            nmap
          ];

          # Root access for experimentation
          users.users.root.password = "playground";

          # Enable SSH
          services.openssh = {
            enable = true;
            settings = {
              PasswordAuthentication = true;
              PermitRootLogin = "yes";
            };
          };

          # Enable Docker and K8s tools
          virtualisation.docker.enable = true;
        };
      };
    };

    # Get primary user (first in the list) for backward compatibility
    getPrimaryUser = host: builtins.head (hostUsers.${host} or ["olafkfreund"]);

    # Get all users for a host
    getHostUsers = host: hostUsers.${host} or ["olafkfreund"];

    # Helper function for package imports
    mkPkgs = pkgs: {
      system = "x86_64-linux";
      config.allowUnfree = true;
      config.allowInsecure = true;
    };

    # Import custom packages
    overlays = [
      (final: prev: {
        customPkgs = import ./pkgs {
          pkgs = final;
        };
      })
      (final: prev: {
        zjstatus = inputs.zjstatus.packages.${prev.system}.default;
      })
    ];

    makeNixosSystem = host: let
      primaryUser = getPrimaryUser host;
      allUsers = getHostUsers host;
      # Only import stylix for desktop/workstation hosts, not servers
      stylixModule =
        if host == "dex5550"
        then []
        else [inputs.stylix.nixosModules.stylix];
    in {
      system = "x86_64-linux";
      specialArgs = {
        pkgs-stable = import nixpkgs-stable (mkPkgs nixpkgs-stable);
        pkgs-unstable = import nixpkgs-unstable (mkPkgs nixpkgs-unstable);
        inherit inputs host;
        username = primaryUser; # Primary user for backward compatibility
        hostUsers = allUsers; # All users for this host
      };
      modules =
        [
          {nixpkgs.overlays = overlays;}
          ./hosts/${host}/configuration.nix
          nur.modules.nixos.default
          home-manager.nixosModules.home-manager
          inputs.nix-colors.homeManagerModules.default
          inputs.nix-snapd.nixosModules.default
          inputs.agenix.nixosModules.default
          nix-index-database.nixosModules.nix-index
          ./home/shell/zellij/zjstatus.nix
          inputs.nixvim.nixosModules.nixvim
          nixai.nixosModules.default
        ]
        ++ stylixModule
        ++ [
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              backupFileExtension = "backup";
              extraSpecialArgs = {
                pkgs-stable = import nixpkgs-stable (mkPkgs nixpkgs-stable);
                pkgs-unstable = import nixpkgs-unstable (mkPkgs nixpkgs-unstable);
                inherit
                  inputs
                  nixpkgs
                  zjstatus
                  spicetify-nix
                  ags
                  agenix
                  razer-laptop-control
                  walker
                  nix-index-database
                  nixpkgs-f2k
                  bzmenu
                  iwmenu
                  home-manager
                  nixpkgs-stable
                  nixpkgs-unstable
                  nix-colors
                  nix-snapd
                  nixvim
                  host
                  ;
                # Only include stylix for non-server hosts
                stylix =
                  if host == "dex5550"
                  then null
                  else stylix;
                username = primaryUser;
                hostUsers = allUsers;
              };

              # Configure home-manager for all users on this host
              users = builtins.listToAttrs (map (user: {
                  name = user;
                  value = import ./Users/${user}/${host}_home.nix;
                })
                allUsers);
              sharedModules = [
                inputs.nixvim.homeManagerModules.nixvim
                nixai.homeManagerModules.default
              ];
            };
          }
        ];
    };
  in {
    nixosConfigurations = {
      razer = nixpkgs.lib.nixosSystem (makeNixosSystem "razer");
      dex5550 = nixpkgs.lib.nixosSystem (makeNixosSystem "dex5550");
      # hp = nixpkgs.lib.nixosSystem (makeNixosSystem "hp");
      p510 = nixpkgs.lib.nixosSystem (makeNixosSystem "p510");
      p620 = nixpkgs.lib.nixosSystem (makeNixosSystem "p620");
      samsung = nixpkgs.lib.nixosSystem (makeNixosSystem "samsung");

      # MicroVM configurations
      dev-vm = microvms.dev-vm;
      test-vm = microvms.test-vm;
      playground-vm = microvms.playground-vm;
    };

    # Expose liveImages and microvms in outputs
    inherit liveImages microvms;

    packages.x86_64-linux = {
      claude-code = import ./home/development/claude-code {
        inherit (nixpkgs.legacyPackages.x86_64-linux) lib buildNpmPackage fetchurl nodejs makeWrapper writeShellScriptBin;
      };
      gemini-cli = nixpkgs.legacyPackages.x86_64-linux.callPackage ./pkgs/gemini-cli {};

      # Add live ISO packages for easy building
      live-iso-p620 = liveImages.p620.config.system.build.isoImage;
      live-iso-razer = liveImages.razer.config.system.build.isoImage;
      live-iso-p510 = liveImages.p510.config.system.build.isoImage;
      live-iso-dex5550 = liveImages.dex5550.config.system.build.isoImage;
      live-iso-samsung = liveImages.samsung.config.system.build.isoImage;
    };
  };
}
