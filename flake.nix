{
  description = "Olaf's flake with Home Manager enabled";

  nixConfig = {
    # Primary caches
    substituters = [
      "https://cache.nixos.org/"
      "https://nix-community.cachix.org/"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];

    # Development and specific package caches
    extra-substituters = [
      "https://cuda-maintainers.cachix.org/"
      "https://hyprland.cachix.org/"
      "https://devenv.cachix.org/"
      "https://cosmic.cachix.org/"
    ];
    extra-trusted-public-keys = [
      "cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E="
      "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
      "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw="
      "cosmic.cachix.org-1:Dya9IyXD4xdBehWjrkPv6rtxpmMdRel02smYzA85dPE="
    ];
  };

  inputs = {
    # Core
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    flake-utils.url = "github:numtide/flake-utils";

    # MCP servers
    mcp-nixos.url = "github:utensils/mcp-nixos";

    # Environment and theming
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    stylix = {
      url = "github:danth/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Noctalia — Quickshell-based Wayland desktop shell (bar, launcher,
    # notifications, lock). Used on niri + labwc (not GNOME). homeModules.default
    # provides programs.noctalia. Follows nixpkgs: the package is a light QML
    # wrapper over pkgs.quickshell (already cached in nixpkgs), so this avoids
    # duplicating the Qt closure and needs no extra cachix.
    noctalia = {
      url = "github:noctalia-dev/noctalia";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Noctalia greeter — greetd login screen matching the Noctalia shell. Ships
    # nixosModules.default (programs.noctalia-greeter) which auto-wires
    # services.greetd + the bundled wlroots compositor. Enabled per-host where
    # we replace GDM with greetd.
    noctalia-greeter = {
      url = "github:noctalia-dev/noctalia-greeter";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # niri — scrollable-tiling Wayland compositor. niri-flake provides the
    # NixOS module (programs.niri) + the home-manager config option
    # (programs.niri.settings). We pin the package to pkgs.niri (nixpkgs) and
    # disable niri-flake's binary cache, so no extra substituter/rebuild dance.
    niri-flake = {
      url = "github:sodiboo/niri-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # mango — dwl-based Wayland compositor (wlroots + scenefx). Its flake
    # provides the NixOS module (programs.mango, wired below) and the
    # home-manager config option (wayland.windowManager.mango, added to
    # home-manager.sharedModules). Third Noctalia session alongside niri/labwc.
    mango = {
      url = "github:mangowm/mango";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Development and utilities
    sops-nix = {
      url = "github:mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Browser and media
    spicetify-nix.url = "github:Gerg-L/spicetify-nix";

    # System utilities
    agenix.url = "github:ryantm/agenix";
    nix-snapd.url = "github:io12/nix-snapd";
    microvm.url = "github:astro/microvm.nix";

    # Secure Boot — v1.0.0 (latest tag) still sets the removed
    # boot.bootspec.enable option, which throws against current nixpkgs
    # (bootspec is now always-on). Pinned to master past that fix.
    lanzaboote = {
      url = "github:nix-community/lanzaboote/001e560fffc8f0235e9db20ebeb4ccde0ade1caf";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Additional tools
    lan-mouse.url = "github:feschber/lan-mouse";
    zjstatus.url = "github:dj95/zjstatus";
    # = tag v2.0.16+claude1.9255.2, commit 5dd948e9 (2026-05-28).
    # Claude binary bump 1.9255.0 -> 1.9255.2. Picks up:
    #   - #660 capture $-prefixed minified names in cowork spawn guard
    #     (refinement to cowork patch from v2.0.15)
    # Carries forward from v2.0.15:
    #   - #657 anchor tray-var extraction on .Tray() literal
    #   - #650 filter .asar paths from --add-dir dispatch + session restore
    # Known caveat carried in: #605 (Electron holds systemd-inhibit
    # forever, blocking suspend while app runs). Razer-relevant.
    # Workaround: close claude-desktop entirely to release inhibitor,
    # or set CLAUDE_KEEP_AWAKE=0 (#645).
    # Bump via /update-claude-code.
    # = tag v2.0.22+claude1.15200.0 (commit cdf934a061, 2026-06-25)
    # Delta from previous pin (v2.0.19+claude1.11847.5): cowork renderer
    # support-gate fix (#743) and upstream tracking up to Claude Desktop
    # 1.15200.0.
    # NOTE: pin to the latest *release* tag, NOT main HEAD — historically main
    # can fail to build (e.g. upstream issue #718). Bump via /update-claude-code.
    # Known open upstream runtime bugs at this pin (UI-only, not build blockers):
    # menu-bar icon glitch on 1.15200.0 (#746), launcher.log O(n²) hang on large
    # logs (#726/#747). We consume upstream's claude-desktop-fhs as-is (no local
    # patch); node-pty/asar handling lives in upstream build.sh.
    claude-desktop-linux.url = "github:aaddrick/claude-desktop-debian/cdf934a06185f7f6564606071044139760cae090";

    # GogMail — keyboard-driven Google Workspace TUI (Gmail/Calendar/Tasks/
    # Drive/Contacts/Chat) built on the gog CLI. Consumed via overlays as
    # pkgs.gogmail; launched from the tmux ai-tools palette + M-c. Uses its
    # own locked nixpkgs (no follows) so the tested Python closure builds
    # as-released. Bump with `nix flake update gogmail`.
    gogmail.url = "github:olafkfreund/gogmail";

    # Claude Code skill catalogue (borghei). flake = false because it's a
    # plain markdown/assets catalogue, not a Nix flake. We symlink one
    # subdirectory (engineering/claude-code-mastery) into ~/.claude/skills/
    # via home/development/claude-code-skills. Bump with `nix flake update
    # claude-skills-borghei` to pull in upstream skill updates.
    claude-skills-borghei = {
      url = "github:borghei/Claude-Skills";
      flake = false;
    };

    # Terminal YouTube browser
    yt-x = {
      url = "github:Benexl/yt-x";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Hardware specific (removed unused razer-laptop-control)

    # Package collections
    nur.url = "github:nix-community/NUR";
    nixpkgs-f2k.url = "github:moni-dz/nixpkgs-f2k";
    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Google Antigravity package
    antigravity-nix = {
      url = "github:jacopone/antigravity-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # COSMIC Desktop applets
    cosmic-applet-spotify = {
      url = "github:nomoth/cosmic-applet-spotify";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Rust toolchain overlay — pulls in newer rustc than current nixpkgs
    # ships. Required by splashboard (needs rustc 1.95+ via sysinfo 0.39).
    # Consumed only by overlays/custom-packages.nix when wiring splashboard.
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # gscratch — i3/Sway-style scratchpad for GNOME Shell (any window, toggle
    # via global shortcut). Consumed by Users/olafkfreund/razer_home.nix.
    gscratch = {
      url = "github:olafkfreund/gscratch";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # gnome-quick-web-apps — GTK4/libadwaita web-app manager. Turn any
    # website into a first-class GNOME desktop app. Consumed by razer +
    # p620 home-manager configs.
    gnome-quick-web-apps = {
      url = "github:olafkfreund/gnome-quick-web-apps";
      inputs.nixpkgs.follows = "nixpkgs";
    };

  };

  outputs =
    { nixpkgs
    , nixpkgs-unstable
    , nur
    , agenix
    , spicetify-nix
    , home-manager
    , nix-index-database
    , zjstatus
    , antigravity-nix
    , mcp-nixos
    , ...
    } @ inputs:
    let
      # ========================================
      # SHARED ARCHITECTURE COMPONENTS
      # ========================================
      # Import centralized user mappings from shared variables
      sharedVariables = import ./hosts/common/shared-variables.nix;

      # Define users per host (can be customized per host if needed)
      hostUsers = {
        p620 = [ "olafkfreund" ];
        razer = [ "olafkfreund" ];
        p510 = [ "olafkfreund" ];
      };

      # Live image builder
      liveImages = import ./lib/live-images.nix {
        inherit nixpkgs inputs hostUsers;
      };

      # ========================================
      # HELPER FUNCTIONS
      # ========================================

      # Get primary user (first in the list) for backward compatibility
      getPrimaryUser = host: builtins.head (hostUsers.${host} or [ "olafkfreund" ]);

      # Get all users for a host
      getHostUsers = host: hostUsers.${host} or [ "olafkfreund" ];

      # ========================================
      # ARCHITECTURE TEMPLATES
      # ========================================

      # Host type templates for configuration reduction (workstation, laptop, server, hybrid)
      hostTypes = import ./lib/hostTypes.nix { inherit (nixpkgs) lib; };

      # Hardware profiles for GPU-specific configurations
      hardwareProfiles = {
        amd = import ./hosts/common/hardware-profiles/amd-gpu.nix;
        nvidia = import ./hosts/common/hardware-profiles/nvidia-gpu.nix;
        intel = import ./hosts/common/hardware-profiles/intel-integrated.nix;
      };

      # ========================================
      # PACKAGE CONFIGURATION
      # ========================================

      # Helper function for package imports
      mkPkgs = _pkgs: system: {
        localSystem = system; # Modern replacement for deprecated 'system' parameter
        config = {
          allowUnfree = true;
          # allowInsecure = false; # REMOVED for security - using targeted permissions
        };
      };

      overlays = import ./overlays { inherit inputs; };

      makeNixosSystem = host:
        let
          primaryUser = getPrimaryUser host;
          allUsers = getHostUsers host;
          # Stylix theming module - re-enabled after upstream cache fix
          stylixModule = [ inputs.stylix.nixosModules.stylix ];
          system = "x86_64-linux";
        in
        {
          inherit system;
          specialArgs = {
            pkgs-unstable = import nixpkgs-unstable (mkPkgs nixpkgs-unstable system);
            inherit inputs host hostTypes;
            username = primaryUser; # Primary user for backward compatibility
            hostUsers = allUsers; # All users for this host
            # Shared variables and hardware profiles for explicit tracking
            inherit sharedVariables hardwareProfiles;
            # MCP servers from flakes
            mcp-nixos-pkg = mcp-nixos.packages.${system}.default;
          };
          modules =
            [
              { nixpkgs.overlays = overlays; }
              ./hosts/${host}/configuration.nix
              nur.modules.nixos.default
              home-manager.nixosModules.home-manager
              inputs.nix-snapd.nixosModules.default
              inputs.agenix.nixosModules.default
              inputs.lanzaboote.nixosModules.lanzaboote
              inputs.niri-flake.nixosModules.niri
              inputs.mango.nixosModules.mango
              inputs.noctalia-greeter.nixosModules.default
              nix-index-database.nixosModules.nix-index
              ./home/shell/zellij/zjstatus.nix
            ]
            ++ stylixModule
            ++ [
              {
                home-manager = {
                  useGlobalPkgs = true;
                  useUserPackages = true;
                  # Use backup command to move files to timestamped directory
                  # This prevents backup file collisions by using unique directories
                  backupCommand = ''
                    backup_dir = "$HOME/.hm-backups/$(date +%Y-%m-%d-%H%M%S)"
                      mkdir - p "$(dirname "$backup_dir/$1 ")"
                      mv "$1" "$backup_dir/$1"
                  '';
                  # Shared modules for all users
                  sharedModules = [
                    {
                      stylix.targets.firefox.enable = false;
                    }
                    # Noctalia shell (programs.noctalia). Enabled per-user only
                    # where the niri/labwc home profile turns it on.
                    inputs.noctalia.homeModules.default
                    # mango compositor config (wayland.windowManager.mango),
                    # enabled per-user in the same niri/labwc home profile.
                    inputs.mango.hmModules.mango
                  ];
                  extraSpecialArgs = {
                    pkgs-unstable = import nixpkgs-unstable (mkPkgs nixpkgs-unstable system);
                    inherit
                      inputs
                      nixpkgs
                      zjstatus
                      spicetify-nix
                      agenix
                      antigravity-nix
                      host
                      ;
                    username = primaryUser;
                    hostUsers = allUsers;
                    # Shared variables and hardware profiles for home-manager
                    inherit sharedVariables hardwareProfiles;
                  };
                  users = builtins.listToAttrs (map
                    (user: {
                      name = user;
                      value = import (./Users + "/${user}/${host}_home.nix");
                    })
                    allUsers);
                };
              }
            ];
        };
    in
    {
      # ========================================
      # HOST CONFIGURATIONS
      # ========================================
      nixosConfigurations = {
        # Workstations (high-performance desktop systems)
        p620 = nixpkgs.lib.nixosSystem (makeNixosSystem "p620"); # AMD workstation (primary AI host)
        p510 = nixpkgs.lib.nixosSystem (makeNixosSystem "p510"); # Intel Xeon server (media server)

        # Laptops (portable systems with power management)
        razer = nixpkgs.lib.nixosSystem (makeNixosSystem "razer"); # Intel/NVIDIA laptop (mobile dev)

        # MicroVM configurations (temporarily disabled for flake restructuring)
        # dev-vm = microvms.dev-vm;
        # test-vm = microvms.test-vm;
        # playground-vm = microvms.playground-vm;
      };

      # ========================================
      # PACKAGES AND APPLICATIONS
      # ========================================
      packages.x86_64-linux =
        let
          pkgs = import nixpkgs {
            system = "x86_64-linux";
            config = {
              allowUnfree = true;
              permittedInsecurePackages = [
                "mdatp"
              ];
            };
          };
        in
        {
          # Custom applications
          aerion = pkgs.callPackage ./pkgs/aerion { };
          claude-code = import ./home/development/claude-code {
            inherit (pkgs) lib buildNpmPackage fetchurl nodejs makeWrapper writeShellScriptBin;
          };
          claude-code-native = pkgs.callPackage ./pkgs/claude-code-native { };
          glim = pkgs.callPackage ./overlays/glim { };
          intune-portal = pkgs.callPackage ./pkgs/intune-portal { };
          kosli-cli = pkgs.callPackage ./pkgs/kosli-cli { };
          opencode = pkgs.callPackage ./home/development/opencode { };
          aurynk = pkgs.callPackage ./pkgs/aurynk { };
          # add-skill = pkgs.callPackage ./pkgs/add-skill { };

          # Security tools
          mdatp = pkgs.callPackage ./pkgs/microsoft-defender-for-endpoint {
            inherit (pkgs) buildFHSEnv;
          };

          # Enterprise tools
          # NOTE: citrix-workspace is provided via overlay (overlays/citrix-workspace.nix)
          # It requires manual tarball download - see pkgs/citrix-workspace/fetch-citrix.sh

          # Icon themes
          neuwaita-icon-theme = pkgs.stdenvNoCC.mkDerivation {
            pname = "neuwaita-icon-theme";
            version = "unstable-2025-01-15";

            src = pkgs.fetchFromGitHub {
              owner = "RusticBard";
              repo = "Neuwaita";
              rev = "4c63e30493ab34558539104309282877ab767798";
              hash = "sha256-NL8/ceugdGNSMpa8G/a4Eolutf5BcN6PXiQ9qDmHM1U=";
            };

            dontBuild = true;
            dontConfigure = true;

            installPhase = ''
              runHook
              preInstall
              mkdir - p $out/share/icons/Neuwaita
              cp - r * $out/share/icons/Neuwaita/
              rm - rf $out/share/icons/Neuwaita/.git *
              runHook postInstall
            '';

            meta = with pkgs.lib; {
              description = "A different take on the Adwaita icon theme";
              homepage = "https://github.com/RusticBard/Neuwaita";
              license = licenses.gpl3Plus;
              platforms = platforms.linux;
            };
          };

          # Documentation site (MkDocs Material, built reproducibly)
          docs = pkgs.callPackage ./docs_gen/site.nix { };

          # Live ISO images
          live-iso-razer = liveImages.liveImages.live-iso-razer.config.system.build.isoImage;

          # Development and deployment tools available as packages
          # (Apps are available separately via apps.x86_64-linux)
        };

      # ========================================
      # DEVELOPMENT ENVIRONMENTS
      # ========================================
      devShells.x86_64-linux =
        let
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
        in
        {
          default = import ./tools/dev.nix { inherit pkgs inputs; };
          testing = import ./tools/testing.nix { inherit pkgs; };
          docs = import ./tools/docs.nix { inherit pkgs; };
        };

      # ========================================
      # VALIDATION AND AUTOMATION
      # ========================================

      # Quality assurance and validation checks
      checks.x86_64-linux = import ./checks/default.nix {
        pkgs = nixpkgs.legacyPackages.x86_64-linux;
        inherit (nixpkgs) lib;
      };

      # Application entries for common workflows
      apps.x86_64-linux =
        let
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
          appPkgs = import ./tools/default.nix { inherit pkgs; };
        in
        {
          deploy = {
            type = "app";
            program = "${appPkgs.deploy}/bin/nixos-deploy";
          };
          test = {
            type = "app";
            program = "${appPkgs.test}/bin/nixos-test";
          };
          build-live = {
            type = "app";
            program = "${appPkgs.build-live}/bin/nixos-build-live";
          };
          dev-utils = {
            type = "app";
            program = "${appPkgs.dev-utils} /bin/nixos-dev-utils";
          };
        };

      # Code formatter for consistent formatting
      formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixpkgs-fmt;
    };
}

