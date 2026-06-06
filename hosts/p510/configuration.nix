{ pkgs
, lib
, hostUsers
, hostTypes
, ...
}:
let
  vars = import ./variables.nix { };
in
{
  # Use workstation template for desktop environment with media server modules
  imports =
    hostTypes.workstation.imports
    ++ [
      # Hardware-specific imports
      ./nixos/hardware-configuration.nix
      ./nixos/power.nix
      ./nixos/boot.nix
      ./nixos/nvidia.nix
      ./nixos/network.nix # Network configuration with dual-port Intel card
      ./nixos/tailscale-serve.nix # Tailscale Serve for media services
      ./nixos/recyclarr.nix # Recyclarr Trash Guides sync
      ../common/nixos/i18n.nix
      ../common/nixos/envvar.nix
      ../common/nixos/host-class.nix
      ../common/nixos/inotify-limits.nix
      ./nixos/cpu.nix
      ./nixos/memory.nix
      ../common/nixos/hosts.nix
      ./nixos/plex.nix
      ./flaresolverr.nix # Cloudflare-bypass proxy for Prowlarr (used by 1337x and any other CF-protected indexer)

      # P510-specific server modules (media server)
      ../../modules/development/default.nix
      ../../modules/secrets/api-keys.nix
      ../../modules/services/ollama.nix
      ../../modules/services/plex-mcp.nix # Plex MCP server (HTTP transport, tailnet-only)
      ../../modules/services/backstage.nix # Backstage developer portal (epic #731, disabled by default)
      ../../modules/containers/k3d.nix # k3d (k3s in Docker) cluster — ArgoCD + Tailscale operator (see docs/applications/k3d-cluster.md)
      ../../modules/services/arr-suite-mcp.nix # *arr suite MCP server (SSE bridge, tailnet-only)
      ../../modules/services/audiobookbay-automated.nix # AudioBookBay search → Transmission
      ../../modules/services/audiobook-import.nix # Completed downloads → Audiobookshelf (LLM + m4b)
      ../../modules/services/audiobook-mcp.nix # Audiobook acquisition + library MCP (SSE)
      ../../modules/services/media-bot.nix # Household media Telegram bot (Ollama NL + webhooks)
      ../../modules/services/bazarr.nix # Subtitle automation for Sonarr/Radarr/Lidarr
      ../../modules/services/kometa # Plex Meta Manager — collections, posters, metadata
      ../../modules/services/plex-auto-languages # Per-show audio/sub track memorization
      ../../modules/services/n8n.nix # Workflow automation (media-recommendation engine)
      # Desktop-specific imports (needed for GNOME):
      # ./nixos/greetd.nix      # Display manager - using GDM instead
      ./nixos/screens.nix # Display configuration - needed for desktop
      ./themes/stylix.nix # Re-enabled after upstream cache fix
      # ../../home/desktop/gnome/default.nix # Home Manager module - can't import here
    ];

  host.class = "headless-rdp";

  # Basic networking configuration (detailed config in ./nixos/network.nix)
  networking = {
    hostName = vars.hostName;

    # Disable IPv6
    enableIPv6 = false;

    # Note: Tailscale is enabled via services.tailscale (built-in NixOS module)
    # Custom networking.tailscale module was removed during anti-pattern cleanup

    # DNS configuration - using 192.168.1.1 (router DNS server)
    nameservers = [ "192.168.1.1" "1.1.1.1" ];
  };

  # Tailscale VPN using built-in NixOS service with subnet routing
  # Security is provided by Tailscale - no need for additional firewall
  services.tailscale = {
    enable = true;
    useRoutingFeatures = "server"; # Enable subnet routing features
    openFirewall = false; # No firewall needed - Tailscale provides security
    # Allow the Tailscale daemon to expose local subnet and accept routes
    extraUpFlags = [
      "--advertise-routes=192.168.1.0/24" # Advertise local subnet
      "--accept-routes" # Accept routes from other nodes
      "--accept-dns=false" # Disable Tailscale DNS - use local DNS only
    ];
  };

  # Use AI provider defaults with workstation profile (now with desktop environment)
  aiDefaults = {
    enable = true;
    profile = lib.mkForce "workstation"; # Force workstation profile for desktop environment
  };

  # Use the new features system instead of multiple lib.mkForce calls
  features = {
    development = {
      enable = true;
      cargo = true;
      github = true;
      go = true;
      java = true;
      lua = true;
      nix = true;
      shell = true;
      devshell = true; # Enable devenv development environment
      python = true;
      nodejs = false; # Temporarily disabled due to version conflict - fix DNS first
    };

    virtualization = {
      enable = true;
      docker = true;
      incus = false;
      podman = true;
      spice = true;
      libvirt = true;
    };

    cloud = {
      enable = true;
      aws = false;
      azure = false;
      google = false;
      k8s = false;
      terraform = false;
    };

    security = {
      enable = true;
      onepassword = true;
      gnupg = true;
    };

    networking = {
      enable = true;
    };

    # Syncthing for ~/.claude and ~/.gemini sync across hosts
    syncthing = {
      enable = true;
      syncClaude = true;
      syncGemini = true;
      masterHost = "p620";
    };

    homeAssistant = {
      enable = true;
      port = 8123;
      enableCloud = true;
      enableCLI = true;
      tailscaleIntegration = true;
      extraComponents = [
        # Additional integrations
      ];
    };

    ai = {
      enable = true;
      antigravity-cli = true;
      # claude-desktop is a GUI app — p510 has GNOME via the workstation
      # template (RDP'd, since host.class = "headless-rdp"), so it CAN
      # run here and is useful for driving the k3d cluster from p510 via
      # RDP when off-LAN.
      claude-desktop = true;
    };

    programs = {
      lazygit = true;
      thunderbird = false;
      obsidian = false;
      office = false;
      webcam = false; # Disabled due to v4l2loopback build failures on P510
      print = false;
    };

    media = {
      droidcam = false; # Disabled due to v4l2loopback build failures on P510
    };

    # COSMIC Desktop disabled - using GNOME for better headless RDP support
    desktop.cosmic = {
      enable = false; # Disabled: compositor not starting properly for headless operation
      useCosmicGreeter = false;
      defaultSession = false;
      installAllApps = false;
    };

    # Remote Desktop support using GNOME Remote Desktop (native RDP support)
    # Note: cosmic-remote-desktop disabled in favor of native GNOME RDP
    desktop.cosmic-remote-desktop = {
      enable = false; # Disabled: using native GNOME Remote Desktop instead
      protocol = "both";
      rdpPort = 3389;
      vncPort = 5900;
      vncPassword = "p510remote";
      allowedNetworks = [ "192.168.1.0/24" "10.0.0.0/8" ];
      disableScreenLock = false;
      disablePowerManagement = true;
    };

    gnome-remote-desktop = {
      enable = true;
    };
  };

  # Enable encrypted API keys
  secrets.apiKeys = {
    enable = true;
    enableEnvironmentVariables = true;
    enableUserEnvironment = true;
  };

  # BOOT PERFORMANCE: Prevent fstrim from blocking boot (saves 8+ minutes)
  services.fstrim-optimization = {
    enable = true;
    preventBootBlocking = true;
  };

  # DISK SPACE MANAGEMENT: Automatic garbage collection to prevent disk full issues
  storage.garbageCollection = {
    enable = true;
    schedule = "weekly";
    deleteOlderThan = "30d";
    keepGenerations = 5;
    optimizeStore = true;
    minFreeSpace = 20; # Keep at least 20GB free
    aggressiveCleanup = false;
  };

  # Enable Recyclarr synchronization
  services.recyclarr-sync.enable = true;

  # Specific service configurations
  # StreamDeck UI disabled for headless operation
  programs.streamdeck-ui.enable = lib.mkForce false;

  # Enable X server (NVIDIA drivers configured in nvidia.nix)
  services.xserver = {
    enable = true;
    displayManager.xserverArgs = [
      "-nolisten tcp"
      "-dpi 96"
    ];
  };

  # Display manager: GDM for headless GNOME RDP access
  desktop.displayManager = {
    backend = "gdm";
    autoLogin = {
      enable = true;
      user = "olafkfreund";
    };
  };

  # GDM greeter visual baseline (only shown when autoLogin can't proceed,
  # e.g. after a session crash). Keeps clock 24h and forces dark colour
  # scheme so the greeter doesn't flash light during boot transitions.
  programs.dconf.profiles.gdm.databases = [{
    settings = {
      "org/gnome/desktop/interface" = {
        clock-format = "24h";
        color-scheme = "prefer-dark";
      };
    };
  }];

  # Desktop manager configuration - Full GNOME for headless RDP access
  services.desktopManager.gnome.enable = true;

  # GNOME services for full desktop functionality.
  # Note: gnome-remote-desktop is enabled (with the headless-listener wiring
  # fix) by features.gnome-remote-desktop above — no need to repeat it here.
  services.gnome = {
    gnome-settings-daemon.enable = true;
    gnome-keyring.enable = true;
    gnome-initial-setup.enable = false;
  };

  # Ensure display manager is enabled in systemd
  systemd.targets.graphical.wants = [ "display-manager.service" ];

  # Fix GNOME Shell GDM typelib issue - multiple approaches
  environment.sessionVariables.GI_TYPELIB_PATH = "${pkgs.gdm}/lib/girepository-1.0";

  # Add GSettings schema path for GDM login screen
  environment.sessionVariables.GSETTINGS_SCHEMA_DIR = "${pkgs.gdm}/share/gsettings-schemas/gdm-${pkgs.gdm.version}/glib-2.0/schemas";

  environment.systemPackages = with pkgs; [
    gdm # Provides the Gdm-1.0 typelib required by GNOME Shell
    gnome-control-center # Provides login-screen schema
    gnome-settings-daemon # Additional GNOME schemas
    # Qt theme control tools for Stylix
    libsForQt5.qt5ct
    kdePackages.qt6ct
    # Custom qwen-code package temporarily disabled due to npm registry network errors
    # (callPackage ../../home/development/qwen-code/default.nix { })
    customPkgs.rmux # Rust tmux-compatible multiplexer + typed SDK for agent orchestration
    # Remote desktop
    rustdesk-flutter
  ];

  # NVIDIA modules now loaded via initrd.kernelModules in nvidia.nix for proper early initialization

  # Environment variables for CUDA support
  environment.variables = {
    CUDA_PATH = "${pkgs.cudaPackages.cudatoolkit}";
    EXTRA_LDFLAGS = "-L/run/opengl-driver/lib";
    EXTRA_CCFLAGS = "-I/run/opengl-driver/include";
    GI_TYPELIB_PATH = "${pkgs.gdm}/lib/girepository-1.0";
    GSETTINGS_SCHEMA_DIR = "${pkgs.gdm}/share/gsettings-schemas/gdm-${pkgs.gdm.version}/glib-2.0/schemas";
  };

  # Docker configuration
  modules.containers.docker = {
    enable = true;
    users = hostUsers; # Use all users for this host
    rootless = false;
  };

  # k3d cluster — runs ArgoCD, watches github.com/olafkfreund/factory-gitops
  # for App-of-Apps manifests. Tailnet exposure for in-cluster services uses
  # the Tailscale SIDECAR pattern (not the operator): the bootstrap unit
  # seeds a `tailscale-auth-key` Secret into each consuming namespace
  # (argocd, factory) so Pods can mount `TS_AUTHKEY` into a sidecar
  # `tailscale` container that registers a tailnet node.
  # See docs/applications/k3d-cluster.md for ops, docs/architecture/k3d-architecture.md
  # for the design, and docs/guides/factory-gitops.md for the sidecar pattern.
  modules.containers.k3d = {
    enable = true;
    argocd.enable = true;
    tailscaleAuthKey.enable = true;
    # Bind kube API to p510's tailnet IP so kubectl from any tailnet
    # device can drive the cluster directly (`kubectl get nodes` against
    # https://100.118.96.32:6443). k3d 5.x's port-publishing logic
    # doesn't honour `0.0.0.0` correctly (empty Docker PortBindings),
    # so an explicit IP is required. Posture: tailnet ACL is default-
    # open + host firewall disabled; auth gates on the kubeconfig
    # bearer token. p510's tailnet IP is stable per-device — Tailscale
    # doesn't renumber unless you delete + re-add the node.
    apiHostBind = "100.118.96.32";
  };

  # Claude Code managed-settings baseline (mirrors p620 + razer): PARR
  # protocol reminder hook + apiKeyHelper baseline. Read-only at
  # /etc/claude-code; user ~/.claude/settings.json remains writable.
  modules.programs.claude-code-managed = {
    enable = true;
    parrProtocol.enable = true;
  };

  # Network-specific overrides that go beyond the network profile
  systemd = {
    services = {
      NetworkManager-wait-online.enable = lib.mkForce false;
      systemd-networkd-wait-online.enable = lib.mkForce false;
    };

    # Disable systemd-networkd completely - using NetworkManager only
    network.enable = lib.mkForce false;
  };

  # User-specific configuration from variables
  users.users.${vars.username} = {
    isNormalUser = true;
    description = vars.fullName;
    extraGroups = vars.userGroups;
    shell = pkgs.zsh;
    packages = with pkgs; [
      vim
      wally-cli
      # Custom qwen-code package temporarily disabled due to npm registry network errors
      # (callPackage ../../home/development/qwen-code/default.nix { })
    ];
  };

  # NVIDIA specific configurations
  hardware.keyboard.zsa.enable = true;

  # Agenix identity configuration - specify where to find decryption keys
  age.identityPaths = [
    "/home/olafkfreund/.ssh/id_ed25519" # User key
    "/etc/ssh/ssh_host_ed25519_key" # Host key (Ed25519)
    "/etc/ssh/ssh_host_rsa_key" # Host key (RSA fallback)
  ];

  # Disable firewall - P510 is on trusted internal network
  # Security is provided by Tailscale ACLs and router firewall
  # Services: Plex, Sonarr, Radarr, NZBGet, Tautulli, etc. need unrestricted access
  networking.firewall.enable = false;

  nixpkgs.config = {
    allowUnfree = true; # Required for NVIDIA drivers
    allowBroken = true;
    permittedInsecurePackages = [ "olm-3.2.16" "dotnet-sdk-6.0.428" "python3.12-youtube-dl-2021.12.17" ];

    # Override nodejs to use nodejs_24 to avoid version conflicts
    packageOverrides = pkgs: {
      nodejs = pkgs.nodejs_24;
    };
  };
  system.stateVersion = "25.11";

  # Local Ollama model server on NVIDIA GPU (CUDA, loopback only)
  features.ollama-server = {
    enable = true;
    package = pkgs.ollama-cuda; # NVIDIA CUDA GPU package
    # Stored on the dedicated 916GB compute pool (870GB free), not the
    # media pool. Models share IOPS with nothing else, and we leave
    # /mnt/media for Plex transcodes + library scans.
    modelsDir = "/mnt/img_pool/ollama/models";
    persistentModels = [ ]; # No persistent models to save VRAM
    # gemma4 for n8n; qwen2.5:7b for reliable strict-JSON audiobook metadata
    # extraction + tool-calling (audiobook-import / audiobook-mcp).
    onDemandModels = [ "gemma4:e4b" "qwen2.5:7b" ];
    keepAlive = "5m"; # Evict from VRAM after 5 minutes of idle
  };

  # Plex MCP server — exposes the local Plex server to AI clients over MCP
  # (Streamable HTTP at http://p510:3010/mcp). Reachable only over the tailnet
  # + LAN; the Plex token is loaded at runtime from agenix (secrets/plex-token.age).
  features.plex-mcp = {
    enable = true;
    listenLanInterface = "eno1"; # P510 onboard Intel I218-LM
  };

  # Backstage developer portal — see docs/backstage.md.
  # Image SHA pinned in modules/services/backstage.nix; bump by editing
  # the module's `image` default after each Freundcloud/backstage CI run.
  # OAuth callback URL on the GitHub OAuth App must match publicUrl:
  #   https://p510.tail833f7.ts.net/backstage/api/auth/github/handler/frame
  features.backstage.enable = true;

  # arr-suite MCP server — exposes Sonarr/Radarr/Prowlarr/Overseerr (and Plex)
  # to AI clients over SSE at http://p510:3011/sse. NZBGeek is reachable via
  # Prowlarr. *arr API keys come from agenix (secrets/arr-suite-mcp-env.age).
  features.arr-suite-mcp = {
    enable = true;
    listenLanInterface = "eno1";
  };

  # AudioBookBay search UI → existing Transmission daemon. Downloads land in
  # /mnt/media/downloads/torrents/audiobooks/<Title>/ (watched by the
  # audiobook-import pipeline). Reachable over the tailnet + LAN, and exposed
  # at https://p510.<tailnet>/audiobooks-dl via tailscale-serve.
  features.audiobookbay-automated = {
    enable = true;
    listenLanInterface = "eno1";
  };

  # Completed audiobook downloads → Audiobookshelf library. Scans the ABB
  # download dir every 5 min, parses release names with the local qwen2.5:7b,
  # merges multi-file books into chaptered M4B via m4b-tool, and places them
  # under /mnt/media/Media/Audiobooks/<Author>/[<Series>/]<Title>/.
  features.audiobook-import = {
    enable = true;
    # ABB torrents land here; SABnzbd (audiobook-only on p510 — the *arr stack
    # uses NZBGet/Transmission) completes Usenet grabs here. Both are watched
    # so NZBGeek audiobooks import too.
    watchDirs = [
      "/mnt/media/downloads/torrents/audiobooks"
      "/mnt/media/downloads/sabnzbd/complete"
    ];
  };

  # Audiobook acquisition + library MCP (SSE on :3012). Exposes search_abb,
  # add_abb, search_usenet (NZBGeek via Prowlarr), grab_usenet (SABnzbd), and
  # Audiobookshelf library lookups for an LLM/Claude agent over the tailnet.
  features.audiobook-mcp = {
    enable = true;
    listenLanInterface = "eno1";
  };

  # Household media Telegram bot — Phase 1.
  # Menu commands (/search /add /queue /status /wanted) + local-LLM
  # natural-language fallback via Ollama (qwen2.5:7b default) + webhook
  # receiver on :8090 ingesting Sonarr/Radarr/Overseerr/audiobook-import
  # events with Telegram inline action buttons.
  #
  # Tailscale-only by design: every webhook source runs on this same host
  # (loopback POSTs); LAN exposure would only widen the attack surface for
  # spoofed notifications. Add `listenLanInterface = "eno1"` here if a
  # future webhook source ever lives off-host.
  #
  # Whitelist (secrets/media-bot-users.age) — edit with:
  #   agenix -e secrets/media-bot-users.age
  # then `sudo systemctl reload media-bot` on p510 to hot-reload.
  features.media-bot = {
    enable = true;
  };

  # Bazarr — subtitle manager for Sonarr/Radarr/Lidarr. Runs on :6767;
  # exposed on tailnet0 + eno1 LAN. First-deploy: open the UI, wire it
  # to Sonarr/Radarr by hand (one-time), set Default Language Profile
  # to Norwegian Bokmål (nb) + English (en) fallback. See the module
  # for the full first-run checklist.
  features.bazarr = {
    enable = true;
    listenLanInterface = "eno1";
  };

  # Kometa (Plex Meta Manager) — collections + metadata for Plex.
  # Phase 1a: dry-run mode, IMDb Top 250 only. Will fail TMDB auth until
  # you grab a free key from themoviedb.org and `agenix -e secrets/
  # kometa-env.age` to fill it in. See modules/services/kometa/default.nix
  # for the full first-run flow.
  features.kometa = {
    enable = true;
  };

  # Plex-Auto-Languages — learns each Plex user's per-show audio + subtitle
  # preferences and applies them to future episodes automatically. Watches
  # Plex via its websocket API (no Plex Pass needed for this path).
  features.plex-auto-languages = {
    enable = true;
  };

  # n8n workflow runtime (localhost:5678) — hosts the "just-finished"
  # media-recommendation workflow that calls Overseerr/Tautulli + local gemma.
  # See docs/plans/2026-05-26-plex-llm-recommendations-design.md.
  features.n8n.enable = true;
}
