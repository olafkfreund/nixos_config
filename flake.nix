{
  description = "Olaf's flake with Home Manager enabled";

  inputs = {
    # Core
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

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
    # Plugin inputs nixarchy also carries (-pkg, -distrobox, -microvm,
    # ai-mirror) follow nixarchy's pins below rather than keeping their own:
    # bump them with `nix flake update nixarchy`. nixarchy-voice is the
    # exception: it tracks its own main (#2483).
    # Followed by nixarchy (below), so `nix flake update` moves nixi itself (nixarchy#1432).
    nixi = {
      url = "github:olafkfreund/nixi-nixarchy";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.omarchy.follows = "nixarchy/omarchy";
    };
    # Flux: phone link (fluxd, flux-cli, shell plugin); features.flux (#2905).
    nixarchy-flux = {
      url = "github:olafkfreund/nixarchy-flux";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixi-companion = {
      url = "github:olafkfreund/nixoarchy-snowflake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixarchy = {
      url = "github:olafkfreund/nixarchy/edge";
      inputs.nixpkgs.follows = "nixpkgs";
      # The same shape as the zen-browser note below, on a different child.
      # nixarchy pins sops-nix at a8627b21 (2026-08-13), which predates
      # nixpkgs removing buildGo125Module on 2026-09-15 -- so the moment any
      # host declares a sops secret, sops-install-secrets fails to build and
      # the error names Go, not sops and not nixarchy. It made hypr-rdp
      # unbuildable (since removed, #2510); kept so any future sops secret
      # builds. Filed upstream.
      inputs.sops-nix.follows = "sops-nix";
      # nixarchy re-exports zen-browser as a package attribute, so its pin is a
      # hard eval dependency for us even though no host installs Zen. Its lock
      # sat on 51df7b8, which passes ffmpeg_7 to wrapFirefox after nixpkgs
      # removed it — every host closure died on an error naming only
      # `environment.etc.dbus-1.source`. Bumping the child node alone is not
      # enough: a full flake update re-resolves it from nixarchy's own lock and
      # puts the broken pin straight back. Drop this once nixarchy's lock is
      # ahead of fdb83f8.
      inputs.zen-browser.follows = "zen-browser";
      # nixarchy#1432: nixi and the companion follow our own inputs, so this
      # flake's `nix flake update` moves them instead of nixarchy's lock.
      inputs.nixi.follows = "nixi";
      inputs.nixi-companion.follows = "nixi-companion";
      # Track nixarchy-voice main ourselves rather than nixarchy's pin, which
      # lags it (#2483); `nix flake update` moves it to the newest commit.
      inputs.nixarchy-voice.url = "github:olafkfreund/nixarchy-voice";
      inputs.nixarchy-voice.inputs.nixpkgs.follows = "nixpkgs";
      inputs.nixarchy-voice.inputs.ai-mirror.follows = "nixarchy/ai-mirror";
      # #2732 slow-login fix, #2880 live editor themes, #2938 Omarchroma 4.1.0, nixarchy-omatheme#60 starship re-render, nixarchy-omatheme#66 Icons; remove once nixarchy pins this commit or later.
      inputs.nixarchy-omatheme.url = "github:olafkfreund/nixarchy-omatheme/e47e9dd8e9c3ae0cc74e784c246bcf6dff8c8adc";
      inputs.nixarchy-omatheme.inputs.nixpkgs.follows = "nixpkgs";
      inputs.nixarchy-omatheme.inputs.home-manager.follows = "home-manager";
      # herdr 1.3.0: menu unloads safely, no keepLoaded (#3139, nixarchy-herdr#33); remove once nixarchy edge pins ef6387f or later.
      # Pins live here, not only in flake.lock: `nix flake update` re-resolves a lock-only pin (#3080).
      inputs.nixarchy-herdr.url = "github:olafkfreund/nixarchy-herdr/ef6387f11458c8b6ce0ff145f3b29f0b83c566f6";
      inputs.nixarchy-herdr.flake = false;
      # gltui v1.17.0 ahead of edge; remove once nixarchy pins 81be198 or later.
      inputs.nixarchy-gltui.url = "github:olafkfreund/nixarchy-gltui/81be1989835bab8131341673e3efed4e23693789";
      inputs.nixarchy-gltui.inputs.nixpkgs.follows = "nixarchy/nixpkgs";
      # ghtui v1.1.1 ahead of edge; remove once nixarchy pins 53b1b0a or later.
      inputs.nixarchy-ghtui.url = "github:olafkfreund/nixarchy-ghtui/53b1b0acaeb82d6ac513ce79950b915a60486da7";
      inputs.nixarchy-ghtui.inputs.nixpkgs.follows = "nixarchy/nixpkgs";
      # #3107 no keepLoaded / no launcher-entry rescans, ahead of edge; remove each once nixarchy pins its rev or later.
      inputs.nixarchy-devenv.url = "github:olafkfreund/nixarchy-devenv/0d56f9c4556361bf6289455e823ab02a3d8af683";
      inputs.nixarchy-devenv.inputs.nixpkgs.follows = "nixarchy/nixpkgs";
      inputs.nixarchy-distrobox.url = "github:olafkfreund/nixarchy-distrobox/431b3b215bd743f2dab4abba47287b9f728fec6c";
      inputs.nixarchy-distrobox.inputs.nixpkgs.follows = "nixarchy/nixpkgs";
      inputs.nixarchy-microvm.url = "github:olafkfreund/nixarchy-microvm/60456c6ecde973e4f3bea6ea0d673e31fecd3d8a";
      inputs.nixarchy-microvm.inputs.nixpkgs.follows = "nixarchy/nixpkgs";
      inputs.nixarchy-hyprsettngs.url = "github:olafkfreund/nixarchy-hyprsettngs/e5d86e9ef270aa90813ca3bc1ab296f4c8fac7c5";
      inputs.nixarchy-hyprsettngs.flake = false;
      # #3144 menus safe to unload, no keepLoaded, ahead of edge; remove each once nixarchy pins its rev or later.
      inputs.nixarchy-pkg.url = "github:olafkfreund/nixarchy-pkg/637b174cecab517d12434d871cd3f59c157b6d88";
      inputs.nixarchy-pkg.inputs.nixpkgs.follows = "nixarchy/nixpkgs";
      inputs.nixarchy-podman.url = "github:olafkfreund/nixarchy-podman/20cbdf74bd6b0253aa865fc31f102b9a0649f1c1";
      inputs.nixarchy-podman.inputs.nixpkgs.follows = "nixarchy/nixpkgs";
      inputs.nixarchy-flatsnap.url = "github:olafkfreund/nixarchy-flatsnap/d266d7fa4da7305fd6e19b936842f2e200e88fef";
      inputs.nixarchy-flatsnap.inputs.nixpkgs.follows = "nixarchy/nixpkgs";
      inputs.nixarchy-flatsnap.inputs.nix-flatpak.follows = "nixarchy/nix-flatpak";

      # nixarchy's NixOS module imports home-manager.nixosModules.home-manager
      # itself. From its own pin that is a second copy of nixos/common.nix, and
      # eval dies with "home-manager.users ... is already declared". Same file
      # from one node = the module system dedupes it.
      inputs.home-manager.follows = "home-manager";
    };

    # Oma, voice control for the Omarchy desktop. Follows this flake's nixpkgs
    # for the same reason nixarchy does: the package wraps ~10 desktop tools
    # onto PATH, and a second nixpkgs would be a second copy of every one.
    nixarchy-voice.follows = "nixarchy/nixarchy-voice";

    # Govee lights plugin for the Omarchy shell (#3144), installed through
    # programs.nixarchy.plugins by hosts/common/nixos/omarchy-govee.nix.
    omagovee = {
      url = "github:olafkfreund/omagovee/9b97dcc60aaf176952df4d08a016ac72ce3766f0";
      flake = false;
    };

    # nixarchy-pkg: the Omarchy menu for managing nixpkgs packages, services
    # and NixOS options. Follows this flake's nixpkgs for the same reason the
    # two above do, though it costs less than they do -- the plugin is QML and
    # a bash adapter, and its closure is jq and the nixarchy writers it calls.
    #
    # Nix installs the plugin; enabling it is runtime state in shell.json and
    # deliberately not managed here, so each machine needs one:
    #   omarchy plugin enable nixarchy.pkg
    nixarchy-pkg.follows = "nixarchy/nixarchy-pkg";

    # nixarchy-distrobox: distrobox on the Omarchy bar and a key -- list,
    # create (every distrobox create flag), enter, start, stop, upgrade and
    # delete boxes, with create and upgrade streamed into the panel. QML only;
    # its closure is the plugin files, and it runs distrobox and podman from
    # PATH.
    #
    # Nix installs the plugin; enabling it is runtime state in shell.json and
    # deliberately not managed here, so each machine needs one:
    #   omarchy plugin enable nixarchy.distrobox
    nixarchy-distrobox.follows = "nixarchy/nixarchy-distrobox";

    # nixarchy-microvm: NixOS MicroVMs on the Omarchy bar and SUPER+ALT+V --
    # disposable VMs through `nixarchy vm` and permanent ones through
    # programs.nixarchy.services.microvm, created, edited and deleted from the
    # keyboard. QML only; its Home Manager module writes the bind fragment
    # ~/.config/hypr/microvm-binds.lua (hosts/common/nixos/omarchy-microvm.nix).
    #
    # Nix installs the plugin; enabling it is runtime state in shell.json and
    # deliberately not managed here, so each machine needs one:
    #   omarchy plugin enable nixarchy.microvm
    nixarchy-microvm.follows = "nixarchy/nixarchy-microvm";

    # nixarchy-winvm: Windows VM panel; a plain plugin source (hosts/common/nixos/omarchy-winvm.nix).
    nixarchy-winvm = {
      url = "github:olafkfreund/nixarchy-winvm";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # nixarchy-omabroadcast: OmaBroadcast (28allday/omabroadcast) live video app,
    # auto-updated nightly upstream; p620 only, hosts/p620/nixos/omabroadcast.nix (#3087).
    nixarchy-omabroadcast = {
      url = "github:olafkfreund/nixarchy-omabroadcast";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # nixarchy-pixelbuds: Pixel Buds battery + ANC bar plugin (fork of
    # rdoupe/omarchy-pixelbuds); hosts/common/nixos/omarchy-pixelbuds.nix.
    nixarchy-pixelbuds = {
      url = "github:olafkfreund/nixarchy-pixelbuds";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # nixarchy-meeting-mode: quiet desktop during calls (DND, stay awake, night
    # light off, omarchy-voice stopped); hosts/common/nixos/omarchy-meeting-mode.nix.
    nixarchy-meeting-mode = {
      url = "github:olafkfreund/nixarchy-meeting-mode";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # nixarchy-meetingai: meeting copilot (daemon, local whisper, Omarchy shell
    # plugin); hosts/common/nixos/omarchy-meetingai.nix.
    nixarchy-meetingai = {
      url = "github:olafkfreund/nixarchy-meetingai";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.nixarchy-meeting-mode.follows = "nixarchy-meeting-mode";
      inputs.home-manager.follows = "home-manager";
    };
    # omaPOD: podcast app + Omarchy bar widget; hosts/common/nixos/omarchy-omapod.nix (#2977).
    omapod = {
      url = "github:olafkfreund/nixarchy-omapod";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
    # omateams: Microsoft Teams web in an Omarchy-themed window, from our fork;
    # hosts/common/nixos/omarchy-omateams.nix (#3028). nixpkgs-qt is not followed:
    # it pins QtWebEngine 6.140.0 (QTBUG-142040) until our nixpkgs has it.
    omateams = {
      url = "github:olafkfreund/omateams";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
    # nixarchy-llm-index: local document and code index served to agents over MCP;
    # hosts/common/nixos/llm-index.nix (#2882). Pinned by rev so an update cannot move it.
    nixarchy-llm-index = {
      url = "github:olafkfreund/nixarchy-llm-index/188bc815bb163159534ad04f5246d9c2dcc07734";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    # gmessages: Google Messages as an Omarchy shell plugin (daemon + QML), on p620
    # for testing; hosts/common/nixos/omarchy-gmessages.nix.
    gmessages = {
      url = "github:olafkfreund/nix-gmsg-tui";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # nixarchy-flea: Flea file manager (prebuilt upstream binaries in an FHS
    # runtime); hosts/common/nixos/omarchy-flea.nix.
    nixarchy-flea = {
      url = "github:olafkfreund/nixarchy-flea";
      inputs.nixpkgs.follows = "nixpkgs";
      # Used only by nixarchy-flea's own checks; follow ours so the lock has one copy.
      inputs.home-manager.follows = "home-manager";
    };

    # ai-mirror: MCP server + bar indicator letting coding agents drive the
    # Omarchy desktop behind a kill switch (hosts/common/nixos/omarchy-ai-mirror.nix).
    # Tracks ai-mirror's default branch (master). Its PRs land as MERGE COMMITS,
    # deliberately not squashes, so revs pinned from a PR branch stay in master's
    # history and old locks keep resolving. Follows nixpkgs so grim, wl-clipboard
    # and PyGObject are the store paths this system already has.
    # Bump with `nix flake update ai-mirror`.
    ai-mirror.follows = "nixarchy/ai-mirror";

    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
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
    microvm.url = "github:astro/microvm.nix";

    # Secure Boot — v1.0.0 (latest tag) still sets the removed
    # boot.bootspec.enable option, which throws against current nixpkgs
    # (bootspec is now always-on). Pinned to master past that fix.
    lanzaboote = {
      url = "github:nix-community/lanzaboote/v1.1.0";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.rust-overlay.follows = "rust-overlay";
    };

    # Additional tools
    lan-mouse.url = "github:feschber/lan-mouse";
    # NOTE: Claude Desktop is no longer a flake input — as of #986 we package
    # Anthropic's OFFICIAL Linux beta .deb ourselves (pkgs/claude-desktop-beta,
    # exposed via overlays/default.nix as pkgs.claude-desktop-linux). The old
    # aaddrick/claude-desktop-debian Windows-repackage input was removed.

    # Claude Code skill catalogue (borghei). flake = false because it's a
    # plain markdown/assets catalogue, not a Nix flake. We symlink one
    # subdirectory (engineering/claude-code-mastery) into ~/.claude/skills/
    # via home/development/claude-code-skills. Bump with `nix flake update
    # claude-skills-borghei` to pull in upstream skill updates.
    claude-skills-borghei = {
      url = "github:borghei/Claude-Skills";
      flake = false;
    };

    # Our own portable Nix skills, installed for Claude, Codex and
    # Antigravity by home/development/claude-code-skills (#1958).
    nix-skills = {
      url = "github:olafkfreund/nix-skills";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
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
    nix-index-database = {
      url = "github:nix-community/nix-index-database";
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

    # The ArtCraft Crafting Apps (#2230): our own flake, prebuilt upstream
    # tarballs pinned by hash. Enabled by features.craftapps on p620 + razer.
    nix-craftapps = {
      url = "github:olafkfreund/nix-craftapps";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # tfm, the mouse-first terminal file manager (Issue #2243): our own flake,
    # upstream release binary pinned by hash. Enabled by features.tfm.
    nixos-tfm = {
      url = "github:olafkfreund/nixos-tfm";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # flyline — Rust readline replacement for Bash, loaded as a bash loadable
    # builtin (dlopen'd .so, `enable -f .../libflyline.so flyline`). This is
    # what makes bash-as-login-shell viable here: it restores the inline
    # autosuggestions, syntax highlighting and fuzzy tab completion that zsh
    # had via deja / zsh-syntax-highlighting / zsh-fzf-tab, none of which have
    # bash equivalents. Same niche as ble.sh, but Rust + ratatui.
    #
    # Upstream ships nixosModules/overlays/packages. We take the package and
    # wire it into home-manager ourselves (home/shell/bash.nix) because there
    # is no homeManagerModule and the module's entire payload is one `enable`
    # line. nixpkgs follows ours deliberately: without it the flake's own pin
    # drags in a second toolchain (863 MiB vs 16.5 MiB of crate deps).
    #
    # Not in nixpkgs and no upstream binary cache, so this is a local Rust
    # build (~72 derivations). Bump with `nix flake update flyline`.
    flyline = {
      url = "github:HalFrgrd/flyline";
      inputs.nixpkgs.follows = "nixpkgs";
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
    , nur
    , agenix
    , spicetify-nix
    , home-manager
    , nix-index-database
    , ...
    } @ inputs:
    let
      # ========================================
      # SHARED ARCHITECTURE COMPONENTS
      # ========================================

      # Define users per host (can be customized per host if needed)
      hostUsers = {
        p620 = [ "olafkfreund" ];
        razer = [ "olafkfreund" ];
        p510 = [ "olafkfreund" ];
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
      hostTypes = import ./lib/hostTypes.nix;


      # ========================================
      # PACKAGE CONFIGURATION
      # ========================================

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
            inherit inputs host hostTypes;
            username = primaryUser; # Primary user for backward compatibility
            hostUsers = allUsers; # All users for this host
            # Shared variables and hardware profiles for explicit tracking
            # MCP servers from flakes
            # mcp-nixarchy is mcp-nixos's fork and ships the same `mcp-nixos` binary;
            # upstream mcp-nixos recurses on nixpkgs' mcp-types since 3ec636 (#2475).
            mcp-nixos-pkg = inputs.nixarchy.inputs.mcp-nixarchy.packages.${system}.default;
          };
          modules =
            [
              { nixpkgs.overlays = overlays; }
              { system.configurationRevision = inputs.self.rev or inputs.self.dirtyRev or null; }
              ./hosts/${host}/configuration.nix
              nur.modules.nixos.default
              home-manager.nixosModules.home-manager
              inputs.agenix.nixosModules.default
              inputs.lanzaboote.nixosModules.lanzaboote
              nix-index-database.nixosModules.nix-index
            ]
            ++ stylixModule
            ++ [
              ({ pkgs, ... }: {
                # nixpkgs-unstable input removed: pkgs-unstable is the same pkgs.
                _module.args.pkgs-unstable = pkgs;
                home-manager = {
                  useGlobalPkgs = true;
                  useUserPackages = true;
                  # Move a colliding file into a timestamped directory instead of
                  # failing activation.
                  #
                  # This must be an EXECUTABLE, not a shell snippet: HM runs it as
                  # argv ("$@" in home-manager.sh) with the file as $1, so a
                  # multi-line string is word-split and its first token exec'd.
                  # The option's own example is "${pkgs.trash-cli}/bin/trash".
                  #
                  # One directory per activation rather than a ".bak" suffix, so a
                  # second collision on the same path cannot clobber the first
                  # backup. `date -Is` avoids % entirely, which would otherwise be
                  # eaten by systemd unit specifier expansion.
                  backupCommand = pkgs.writeShellScript "hm-backup-file" ''
                    set -euo pipefail
                    backup_dir="''${HOME}/.hm-backups/$(date -Is)"
                    mkdir -p "$(dirname "$backup_dir/$1")"
                    mv "$1" "$backup_dir/$1"
                  '';
                  # Shared modules for all users
                  sharedModules = [
                    ({ pkgs, ... }: {
                      stylix.targets.firefox.enable = false;
                      _module.args.pkgs-unstable = pkgs;
                    })
                  ];
                  extraSpecialArgs = {
                    inherit
                      inputs
                      nixpkgs
                      spicetify-nix
                      agenix
                      host
                      ;
                    username = primaryUser;
                    hostUsers = allUsers;
                    # Shared variables and hardware profiles for home-manager
                  };
                  users = builtins.listToAttrs (map
                    (user: {
                      name = user;
                      value = import (./Users + "/${user}/${host}_home.nix");
                    })
                    allUsers);
                };
              })
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
      };

      # ========================================
      # PACKAGES AND APPLICATIONS
      # ========================================
      packages.x86_64-linux =
        let
          pkgs = import nixpkgs {
            system = "x86_64-linux";
            inherit overlays;
            config = {
              allowUnfree = true;
              permittedInsecurePackages = [
                "mdatp"
              ];
            };
          };
        in
        {
          # Custom applications (defined once, in overlays/ and pkgs/default.nix)
          inherit (pkgs) aerion claude-code-native codex-bin glim intune-portal;
          inherit (pkgs.customPkgs) kosli-cli aurynk;
          # Upstream binary: the nixpkgs build cannot run a prompt (#1859).
          opencode-bin = pkgs.callPackage ./pkgs/opencode-bin { };

          # Security tools
          mdatp = pkgs.callPackage ./pkgs/microsoft-defender-for-endpoint {
            inherit (pkgs) buildFHSEnv;
          };

          # Enterprise tools
          # NOTE: citrix-workspace is provided via overlay (overlays/citrix-workspace.nix)
          # It requires manual tarball download - see pkgs/citrix-workspace/fetch-citrix.sh

          # Documentation site (MkDocs Material, built reproducibly)
          docs = pkgs.callPackage ./docs_gen/site.nix { };

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
        };

      # Code formatter for consistent formatting
      formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixpkgs-fmt;
    };
}

