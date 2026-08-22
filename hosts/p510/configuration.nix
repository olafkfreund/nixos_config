{ config
, pkgs
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
      ./nixos/resilience.nix # Watchdog + sshd limits + oomd (post-2026-07-08 freeze)
      ../common/nixos/hosts.nix
      ./nixos/plex.nix
      ./flaresolverr.nix # Cloudflare-bypass proxy for Prowlarr (used by 1337x and any other CF-protected indexer)

      # P510-specific server modules (media server)
      ../../modules/development/default.nix
      ../../modules/secrets/api-keys.nix
      ../../modules/services/ollama.nix
      ../../modules/services/plex-mcp.nix # Plex MCP server (HTTP transport, tailnet-only)
      ../../modules/services/sqlite-backup.nix # sqlite snapshots off the failing media disk
      ../../modules/services/backstage.nix # Backstage developer portal (epic #731, disabled by default)
      ../../modules/containers/k3d.nix # k3d (k3s in Docker) cluster — ArgoCD + Tailscale operator (see docs/applications/k3d-cluster.md)
      ../../modules/services/arr-suite-mcp.nix # *arr suite MCP server (SSE bridge, tailnet-only)
      ../../modules/services/audiobookbay-automated.nix # AudioBookBay search → Transmission
      ../../modules/services/torrent-vpn.nix # Transmission confined to a ProtonVPN namespace
      ../../modules/services/audiobook-import.nix # Completed downloads → Audiobookshelf (LLM + m4b)
      ../../modules/services/audiobook-mcp.nix # Audiobook acquisition + library MCP (SSE)
      ../../modules/services/media-bot.nix # Household media Telegram bot (Ollama NL + webhooks)
      ../../modules/services/bazarr.nix # Subtitle automation for Sonarr/Radarr/Lidarr
      ../../modules/services/kometa # Plex Meta Manager — collections, posters, metadata
      ../../modules/services/plex-auto-languages # Per-show audio/sub track memorization
      ../../modules/services/ntfy.nix # Push notification server (ntfy-sh)
      ../../modules/services/cloudflared.nix # Cloudflare Tunnel — public ingress (CGNAT-safe)
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

    # DNS: no static nameservers. NetworkManager + systemd-resolved (nixos/network.nix)
    # already pick up the router's DHCP-advertised DNS (192.168.1.254, verified working),
    # and resolved's built-in fallback list covers 1.1.1.1/8.8.8.8/9.9.9.9 if that ever
    # fails. A hardcoded router IP is exactly what went stale and dead (192.168.1.1) when
    # the router changed — DHCP tracks that automatically, a static entry does not.
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
        "starlink"
        "nest"
        "ffmpeg"
        "stream"
      ];
      dashboards = {
        starlink-status = {
          title = "Starlink";
          icon = "mdi:satellite-uplink";
          yaml = ''
            title: Starlink
            views:
              - title: Overview
                path: overview
                icon: mdi:satellite-uplink
                cards:
                  - type: glance
                    title: Status
                    columns: 4
                    entities:
                      - entity: binary_sensor.starlink_connectivity
                        name: Online
                      - entity: binary_sensor.starlink_obstructed
                        name: Obstructed
                      - entity: binary_sensor.starlink_heating
                        name: Heating
                      - entity: binary_sensor.starlink_thermal_throttle
                        name: Throttled
                  - type: entities
                    title: Throughput & Latency
                    entities:
                      - sensor.starlink_downlink_throughput
                      - sensor.starlink_uplink_throughput
                      - sensor.starlink_ping
                      - sensor.starlink_ping_drop_rate
                  - type: history-graph
                    title: Throughput (24h)
                    hours_to_show: 24
                    entities:
                      - sensor.starlink_downlink_throughput
                      - sensor.starlink_uplink_throughput
                  - type: history-graph
                    title: Latency (24h)
                    hours_to_show: 24
                    entities:
                      - sensor.starlink_ping
                  - type: entities
                    title: Data & Power
                    entities:
                      - sensor.starlink_download
                      - sensor.starlink_upload
                      - sensor.starlink_power
                      - sensor.starlink_energy
                  - type: entities
                    title: Dish Status
                    entities:
                      - sensor.starlink_last_restart
                      - binary_sensor.starlink_mast_near_vertical
                      - binary_sensor.starlink_motors_stuck
                      - binary_sensor.starlink_ethernet_speeds
                      - binary_sensor.starlink_update
                      - binary_sensor.starlink_unexpected_location
                      - binary_sensor.starlink_roaming_mode
                      - binary_sensor.starlink_sleep
                  - type: entities
                    title: Sleep Schedule
                    entities:
                      - switch.starlink_sleep_schedule
                      - time.starlink_sleep_start
                      - time.starlink_sleep_end
                  - type: horizontal-stack
                    cards:
                      - type: button
                        name: Stow
                        entity: switch.starlink_stowed
                        icon: mdi:satellite
                        tap_action:
                          action: toggle
                      - type: button
                        name: Restart
                        entity: button.starlink_restart
                        icon: mdi:restart
                        tap_action:
                          action: call-service
                          service: button.press
                          service_data:
                            entity_id: button.starlink_restart
                          confirmation:
                            text: "Restart Starlink dish? Internet will drop for ~2 minutes."
          '';
        };

        nest-cameras = {
          title = "Cameras";
          icon = "mdi:cctv";
          yaml = ''
            title: Cameras
            views:
              - title: Live
                path: live
                icon: mdi:cctv
                cards:
                  - type: picture-glance
                    title: Front Door
                    camera_image: camera.front_door_doorbell
                    camera_view: auto
                    entities:
                      - event.front_door_doorbell_chime
                      - event.front_door_doorbell_motion
                  - type: picture-glance
                    title: Kitchen
                    camera_image: camera.kitchentop
                    camera_view: auto
                    entities:
                      - event.kitchentop_motion
                  - type: picture-glance
                    title: Master Bedroom
                    camera_image: camera.master_bedroom
                    camera_view: auto
                    entities:
                      - event.master_bedroom_motion
              - title: Events
                path: events
                icon: mdi:bell-alert
                cards:
                  - type: logbook
                    title: Recent Camera Events (24h)
                    hours_to_show: 24
                    entities:
                      - event.front_door_doorbell_chime
                      - event.front_door_doorbell_motion
                      - event.kitchentop_motion
                      - event.master_bedroom_motion
          '';
        };
      };
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

    # /home lives on the WD10EZEX (CMR, 7200rpm): 156 MB/s synchronous writes
    # with 850GB free. The previous home, /mnt/img_pool, is an ST1000LM035 —
    # an SMR laptop drive that sustained only 9.5 MB/s under load and 19.8 MB/s
    # idle, with ~450ms write latency. That starved containerd image pulls to
    # ~600 B/s and pushed postgres fsyncs past 70s, so probes killed healthy
    # pods and the k3d cluster could not converge. Space was never the issue;
    # write latency was.
    dataRoot = "/home/docker";
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
    # PV backing store follows Docker off the SMR pool onto /home. The
    # module default (/mnt/img_pool/k3d/storage) was chosen to keep cluster
    # PVCs away from the media library's IOPS, which still holds — /home is
    # simply the faster of the two non-media disks.
    storageDir = "/home/k3d/storage";
    argocd.enable = true;
    tailscaleAuthKey.enable = true;
    factorySecrets.enable = true; # #807: durably seed all factory ns Secrets from agenix
    # Without this /home fills with per-commit factory images: 651GB reclaimed
    # by hand on 2026-08-13 (83% -> 8%). Sunday 04:00 keeps the churn off the
    # media server's evening peak.
    imageGc = {
      enable = true;
      dates = "Sun 04:00";
    };
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
    permittedInsecurePackages = [ "olm-3.2.16" "dotnet-sdk-6.0.428" "python3.12-youtube-dl-2021.12.17" "python3.14-youtube-dl-2021.12.17" ];

    # Override nodejs to use nodejs_24 to avoid version conflicts
    packageOverrides = pkgs: {
      nodejs = pkgs.nodejs_24;
    };
  };
  system.stateVersion = "25.11";

  # p510 is a headless media server (Plex, NZBGet, k3s microvms) and is only
  # ever deployed on explicit request — never unattended. The global
  # system.autoUpgrade in modules/nix/nix.nix pulled and switched this host
  # nightly at ~04:00, which is exactly what we don't want here: an unreviewed
  # switch can restart media services, and its user-activation step fails every
  # run anyway (switch-to-configuration reloads the user dbus-broker and then
  # talks over the dead connection, so nixos-upgrade.service reported failure
  # each morning while having actually applied the upgrade).
  # Deploy with `just p510` instead.
  system.autoUpgrade.enable = lib.mkForce false;

  # Local Ollama model server on NVIDIA GPU (CUDA).
  # Bound to 0.0.0.0:11434 with OLLAMA_ORIGINS=* so tailnet/LAN clients
  # and browser UIs can hit it directly. p510's firewall is disabled —
  # exposure is gated at the network edge (Tailscale ACLs + router).
  features.ollama-server = {
    enable = true;
    package = pkgs.ollama-cuda; # NVIDIA CUDA GPU package
    host = "0.0.0.0"; # Tailnet + LAN reachable
    # Deliberately left on /mnt/img_pool despite that pool being the slow SMR
    # drive. Two reasons it is the right disk for *this* service:
    #
    #   1. ollama.service runs DynamicUser with ProtectHome=yes, so /home is
    #      replaced by an empty tmpfs for it — a modelsDir under /home fails
    #      with "mkdir: permission denied" no matter what ReadWritePaths says,
    #      and DynamicUser's uid changes each start so ownership cannot be
    #      pinned outside systemd's StateDirectory.
    #   2. Model loading is large sequential reads, which SMR serves at full
    #      speed. Only sustained random *writes* collapse on shingled media —
    #      that is what starved containerd and postgres, not this.
    #
    # /mnt/media stays reserved for Plex transcodes and library scans.
    modelsDir = "/mnt/img_pool/ollama/models";
    persistentModels = [ ]; # No persistent models to save VRAM
    # qwen2.5:7b for reliable strict-JSON audiobook metadata extraction +
    # tool-calling (audiobook-import / audiobook-mcp).
    #
    # qwen3.8:27b is deliberately ABSENT here (it is p620's persistent
    # default). This host's PSU is rated 490W and already cannot cover a 135W
    # Xeon plus a 290W-limit 3070 Ti and a 170W-limit 3060 — three hard power
    # cuts on 19/20 Aug 2026, one of them six seconds into an ollama model
    # load. An 18GB dense model does not fit either card alone, so ollama
    # would have to spin up BOTH GPUs to hold it: precisely the transient
    # that kills the box. See docs/plans/2026-08-20-k3d-p510-to-p620-migration.md.
    onDemandModels = [ "gemma4:e4b" "qwen2.5:7b" "gemma4:12b" "qwen2.5-coder:14b" ];
    keepAlive = "5m"; # Evict from VRAM after 5 minutes of idle
  };

  # Bind Ollama to all interfaces (incl. Tailscale 100.118.96.32) so the AIFactory
  # portal at aifactory.freundcloud.org.uk can reach it. Firewall disabled on p510;
  # access is gated by Tailscale ACLs.
  services.ollama.host = lib.mkForce "0.0.0.0";

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
  #   https://backstage.freundcloud.org.uk/api/auth/github/handler/frame
  # (was https://p510.tail833f7.ts.net/backstage/api/auth/github/handler/frame
  #  when the tailnet path-routed setup was the only ingress; that URL still
  #  works for the host-level tailscale-serve path but won't be the OAuth
  #  callback target anymore.)
  features.backstage = {
    enable = true;
    # Cloudflare Tunnel public ingress — see features.cloudflared below.
    # Backstage uses this for app.baseUrl, backend.baseUrl, CORS origin,
    # and OAuth callback construction; the running container must be
    # told to serve at root (no /backstage prefix) so cloudflared can
    # proxy `Host: backstage.freundcloud.org.uk` straight through.
    publicUrl = "https://backstage.freundcloud.org.uk";
  };

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

  # Torrent traffic isolation. Transmission runs inside a network namespace
  # whose only route out is a ProtonVPN WireGuard tunnel, so peer traffic never
  # carries this host's WAN address and a dropped tunnel stops downloads rather
  # than leaking them. Nothing else on p510 is routed through the VPN.
  #
  # The values below come from a WireGuard config downloaded at
  # account.protonvpn.com → Downloads → WireGuard configuration. Pick a server
  # flagged P2P and turn NAT-PMP on, or seeding gets no inbound peers. Only the
  # PrivateKey is secret; it lives in agenix and is read at service start.
  # Proton hands out a dual-stack config; only the v4 half is used here. p510
  # runs with enableIPv6 = false, and omitting the v6 address and ::/0 route
  # means the namespace has no IPv6 path at all rather than an unrouted one.
  features.torrentVpn = {
    enable = true;
    address = "10.2.0.2/32"; # [Interface] Address (v4)
    peer = {
      publicKey = "8/kdhoN9UcJuptbdwaVqfkTGpQDZZC0bOGs5Dr2F2zg="; # NL#733
      endpoint = "169.150.196.130:51820";
    };
    privateKeyFile = config.age.secrets."proton-wireguard-key".path;
  };

  # [Interface] PrivateKey from the ProtonVPN WireGuard config, on its own line
  # with nothing else in the file. Rotate by downloading a fresh config and:
  #   agenix -e secrets/proton-wireguard-key.age
  age.secrets."proton-wireguard-key" = {
    file = ../../secrets/proton-wireguard-key.age;
    mode = "0400";
  };

  # Completed audiobook downloads → Audiobookshelf library. Scans the ABB
  # download dir every 5 min, parses release names with the local qwen2.5:7b,
  # merges multi-file books into chaptered M4B via m4b-tool, and places them
  # under /mnt/media/Media/Audiobooks/<Author>/[<Series>/]<Title>/.
  # The Plex library database lives on /mnt/media — the 12TB ST12000NM0127
  # (ZJV2NZE9) with 2896 reallocated and 656 pending sectors, no RAID, and no
  # other copy. Watch history and curation are the only things here that cannot
  # be re-downloaded, and they are ~1GB. Snapshot them onto /mnt/img_pool,
  # which is a different physical disk.
  features.sqlite-backup = {
    enable = true;
    # Plex's two (module default) plus the *arr trio. All of them keep their
    # state on /mnt/media, and Sonarr/Radarr's own Backups/ directories are on
    # that same disk — which protects against a bad upgrade, not a dying drive.
    # ~1.1GB total: library curation, quality profiles, indexer config and
    # download history that would take days to rebuild by hand.
    databases = [
      "${config.services.plex.dataDir}/Plex Media Server/Plug-in Support/Databases/com.plexapp.plugins.library.db"
      "${config.services.plex.dataDir}/Plex Media Server/Plug-in Support/Databases/com.plexapp.plugins.library.blobs.db"
      "/mnt/media/sonarr/sonarr.db"
      "/mnt/media/radarr/radarr.db"
      "/mnt/media/lidarr/lidarr.db"
    ];
    readPaths = [ "/mnt/media" ];
  };

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

  features.ntfy = {
    enable = true;
    baseUrl = "https://ntfy.freundcloud.org.uk";
    # port defaults to 2586; attachmentSizeLimit to 15M; attachmentTotalLimit to 2G
    #
    # After first deploy, create an admin account:
    #   ssh p510 -- sudo ntfy user add --role=admin olafkfreund
    #   ssh p510 -- sudo ntfy user change-pass olafkfreund
    #
    # Then subscribe at https://ntfy.freundcloud.org.uk (web app) or the
    # ntfy mobile app (iOS / Android) using the same credentials.
    #
    # The Cloudflare DNS CNAME must be created once:
    #   cloudflared tunnel route dns p510-home ntfy.freundcloud.org.uk
  };

  # Cloudflare Tunnel — public ingress under freundcloud.org.uk.
  # Bootstrap (one-time):
  #   1. On a workstation with browser: `cloudflared login` (need
  #      freundcloud.org.uk added to Cloudflare account first)
  #   2. `cloudflared tunnel create p510-home` — note the printed UUID;
  #      update the tunnelId below.
  #   3. Copy ~/.cloudflared/cert.pem and ~/.cloudflared/<UUID>.json
  #      into agenix (manage-secrets.sh edit cloudflared-cert / -credentials).
  #   4. `cloudflared tunnel route dns p510-home backstage.freundcloud.org.uk`
  #      (and same for each other hostname below) — creates the
  #      Cloudflare DNS CNAMEs once.
  # Module documentation: modules/services/cloudflared.nix
  features.cloudflared = {
    enable = true;
    # Tunnel created via `cloudflared tunnel create p510-home`; the matching
    # credentials.json is stored as agenix `cloudflared-credentials`.
    tunnelId = "db4e80d3-d24b-4bb0-8bfd-3cffcb6c628f";
    ingress = {
      # Backstage is the safest first route — it's already a clean HTTP
      # service on this host (podman, port 7007). Cluster services come
      # in round 2 once a Traefik Ingress lands inside k3d.
      #
      # Note: features.backstage.publicUrl was changed to match this URL,
      # so Backstage serves at root (no /backstage path prefix). The
      # GitHub OAuth App's callback URL must be updated to
      # https://backstage.freundcloud.org.uk/api/auth/github/handler/frame
      # at github.com/settings/applications/<your-app>.
      "backstage.freundcloud.org.uk" = "http://localhost:7007";

      # Media stack — every service listed below already binds 127.0.0.1
      # (or 0.0.0.0 on eno1 LAN) on p510. cloudflared proxies inbound
      # from Cloudflare's edge straight to each loopback port. Each
      # hostname needs a matching Cloudflare DNS CNAME — created with:
      #   cloudflared tunnel route dns p510-home <hostname>
      # (on any host that has access to the agenix-decrypted cert.pem;
      # p510 itself works post-deploy.)
      #
      # NOTE on auth: Cloudflare Tunnel does NOT add an auth layer; each
      # service's own auth applies (NZBGet ControlPassword, Sonarr API
      # key, Plex login, etc.). For services that ship no auth (some of
      # the *arr UIs in default mode), exposure to the public internet
      # means anyone with the URL has full UI access. If that matters,
      # gate with Cloudflare Access at the zone level (free, click-only
      # config in the Zero Trust dashboard).
      "plex.freundcloud.org.uk" = "http://localhost:32400";
      "overseerr.freundcloud.org.uk" = "http://localhost:5055";
      "tautulli.freundcloud.org.uk" = "http://localhost:8181";
      "sonarr.freundcloud.org.uk" = "http://localhost:8989";
      "radarr.freundcloud.org.uk" = "http://localhost:7878";
      # Transmission RPC/web — protected by rpc-authentication (agenix
      # transmission-rpc). One-time DNS route needed to publish the CNAME:
      #   cloudflared tunnel route dns p510-home transmission.freundcloud.org.uk
      "transmission.freundcloud.org.uk" = "http://localhost:9091";
      "lidarr.freundcloud.org.uk" = "http://localhost:8686";
      "bazarr.freundcloud.org.uk" = "http://localhost:6767";
      "nzbget.freundcloud.org.uk" = "http://localhost:6789";
      "sabnzbd.freundcloud.org.uk" = "http://localhost:8080";
      "audiobookshelf.freundcloud.org.uk" = "http://localhost:13378";
      # ntfy-sh — self-hosted push notifications. Runs on loopback; auth enforced
      # via deny-all default (agenix ntfy-env). Create the DNS CNAME once:
      #   cloudflared tunnel route dns p510-home ntfy.freundcloud.org.uk
      "ntfy.freundcloud.org.uk" = "http://localhost:2586";
    };

    # Warm-ping each origin every 2 minutes so idle apps (Backstage Node
    # runtime, *arr UIs) don't cold-start on the first public hit
    # and render a blank page while they boot. Hits localhost origins
    # only; never touches Cloudflare's edge.
    keepalive.enable = true;
  };
}
