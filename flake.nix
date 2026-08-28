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

    # Development and specific package caches. Only caches with an actual
    # consumer belong here: every extra substituter costs a round-trip per
    # uncached path. hyprland/cosmic were dropped (#1457) — no hyprland flake
    # input (we build pkgs.hyprland), and desktop.cosmic.enable is false on
    # every host.
    extra-substituters = [
      "https://cuda-maintainers.cachix.org/"
      "https://devenv.cachix.org/"
    ];
    extra-trusted-public-keys = [
      "cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E="
      "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw="
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

    # Omarchy vendored for NixOS -- adds the Omarchy desktop as an extra
    # session on razer. Follows this flake's nixpkgs on purpose: the module
    # takes its package from `pkgs.extend`, so following keeps Omarchy's ~80
    # runtime dependencies as the same store paths this system already has
    # rather than a second copy from nixarchy's own nixpkgs.
    nixarchy = {
      url = "github:olafkfreund/nixarchy";
      inputs.nixpkgs.follows = "nixpkgs";
    };


    # DankCalendar (dcal) — calendar daemon by the DankMaterialShell authors.
    # Connects Local/Google/Microsoft/CalDAV/iCloud accounts and serves them
    # over a unix socket; DMS's CalendarDankBackend discovers
    # $XDG_RUNTIME_DIR/dankcal-*.sock and prefers it over the khal backend,
    # which is read-only. Provides homeModules.dank-calendar (used by
    # home/desktop/dank-calendar) and packages.default, a buildGoModule whose
    # Go version is parsed out of core/go.mod so it cannot drift. The
    # dank-qml-common git submodule is upstream's own flake input, so nothing
    # here needs fetchSubmodules.
    #
    # Pinned to a release tag: this is a fast-moving 0.x (v0.2.7, 2026-07-24).
    # Requires DMS >= 1.5 for the dankcal backend to exist at all; nixos-unstable
    # ships dms-shell 1.5.3, so plain pkgs.dms-shell satisfies that.
    dankcalendar = {
      url = "github:AvengeMedia/dankcalendar/v0.2.7";
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
      url = "github:nix-community/lanzaboote/v1.1.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Additional tools
    lan-mouse.url = "github:feschber/lan-mouse";
    zjstatus.url = "github:dj95/zjstatus";
    # NOTE: Claude Desktop is no longer a flake input — as of #986 we package
    # Anthropic's OFFICIAL Linux beta .deb ourselves (pkgs/claude-desktop-beta,
    # exposed via overlays/default.nix as pkgs.claude-desktop-linux). The old
    # aaddrick/claude-desktop-debian Windows-repackage input was removed.

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
    nur = {
      url = "github:nix-community/NUR";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixpkgs-f2k = {
      url = "github:moni-dz/nixpkgs-f2k";
      inputs.nixpkgs.follows = "nixpkgs";
    };
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

    # herdr — TUI "agent multiplexer" (tmux/zellij for AI coding agents).
    # Single Rust binary, local Unix-socket API, no daemon/root/network.
    # Its flake builds a vendored libghostty-vt via zig (deps pre-fetched
    # offline in-repo), exposed as packages.default. Consumed via overlay
    # as pkgs.herdr on the interactive-host developer profile (p620 + razer).
    # Bump with `nix flake update herdr`.
    herdr = {
      url = "github:ogulcancelik/herdr";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.rust-overlay.follows = "rust-overlay";
    };

    # seance — Zig terminal multiplexer that tracks AI coding agents. Upstream
    # ships a working flake (pkg/nix/package.nix), so there is nothing to
    # package locally; it is consumed via overlay as pkgs.seance.
    #
    # The URL must be git+https with submodules=1: seance vendors a patched
    # ghostty as a git SUBMODULE and its package.nix reads
    # ghostty/nix/build-support/*. The `github:` fetcher does not fetch
    # submodules, so `github:no1msd/seance` fails at eval with
    # "path .../ghostty/nix/build-support/gi-typelib-path.nix does not exist".
    # Bump by moving the ref= tag.
    seance = {
      url = "git+https://github.com/no1msd/seance?submodules=1&ref=refs/tags/v0.1.4";
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
                    # DankCalendar daemon (programs.dank-calendar). Enabled
                    # per-user via home/desktop/dank-calendar; the module is
                    # inert until that profile turns it on.
                    inputs.dankcalendar.homeModules.dank-calendar
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

