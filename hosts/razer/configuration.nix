{ pkgs
, config
, lib
, hostUsers
, hostTypes
, ...
}:
let
  vars = import ./variables.nix { };
in
{
  # Use laptop template and add Razer-specific modules
  imports = hostTypes.laptop.imports ++ [
    # Hardware-specific imports
    ./nixos/hardware-configuration.nix
    ./nixos/screens.nix
    ./nixos/power.nix
    ./nixos/boot.nix
    ./nixos/secure-boot.nix # Secure Boot enabled with lanzaboote (issue #376)
    ./nixos/shim.nix # Microsoft-signed shim + MOK enrollment for Razer's locked PK (issue #376)
    ./nixos/nvidia.nix
    ./nixos/cpu.nix
    ./nixos/laptop.nix
    ./nixos/memory.nix
    ./themes/stylix.nix # Re-enabled after upstream cache fix
    ./nixos/nixarchy.nix # Omarchy desktop, as an extra session
    ../common/nixos/dev-workstation.nix

    # Razer-specific additional modules
    ../../modules/development/default.nix
    ../../modules/security/secrets.nix
    ../../modules/secrets/api-keys.nix
    ../../modules/containers/docker.nix
    ../../modules/services/meeting-transcribe.nix # meet CLI (client; offloads processing to p620)
    ../../modules/programs/agent-voice.nix
    ../../modules/programs/claude-swarm-reaper.nix
  ];

  host.class = "laptop";

  # NOPASSWD sudo for wheel members on razer.
  # Remote deploys (`nhs razer` / `just update-commit-deploy razer`, see
  # scripts/update-commit-deploy.sh) run `nh os switch --target-host razer`,
  # where `razer` resolves via the `Host razer` entry in ~/.ssh/config (the
  # `.lan` search domain no longer exists after the router change). This
  # invokes the post-switch activation via `sudo systemd-run ...
  # switch-to-configuration switch`. Without NOPASSWD the remote sudo step
  # fails with exit 4 ("did you forget --ask-sudo-password?") — the system
  # DOES activate fully (via the early non-sudo path), but the deploy
  # returns non-zero noise. Single-user personal laptop: acceptable
  # trade-off for a clean idempotent deploy.
  security.sudo.wheelNeedsPassword = false;

  # Consolidated networking configuration
  networking = {
    # Set hostname from variables
    inherit (vars) hostName;

    # Choose networking profile: "desktop", "server", or "minimal"
    profile = "desktop";

    # Note: Tailscale is enabled via services.tailscale (built-in NixOS module)
    # Custom networking.tailscale module was removed during anti-pattern cleanup

    # Use NetworkManager for simple network management
    networkmanager = {
      enable = true;
      dns = "default"; # Use NetworkManager's built-in DNS
      # Configure settings using new structured format
      settings = {
        main = {
          dns = "default";
        };
        # Note: global DNS domain settings are not supported in structured format
        # Will use networking.nameservers for DNS configuration instead
      };
    };
    useNetworkd = false;

    # Set custom nameservers as fallback
    nameservers = [
      "1.1.1.1"
      "8.8.8.8"
    ];

    # Firewall disabled to allow all network access including SSH
    firewall.enable = lib.mkForce false;
  };

  # Tailscale VPN using built-in NixOS service
  services.tailscale = {
    enable = true;
    # "none": do not accept subnet routes. razer is directly on 192.168.1.0/24,
    # and p510 advertises that same /24 as a subnet route. With accept-routes on,
    # razer's routing table 52 sent LAN-destined replies back through tailscale0,
    # causing asymmetric routing that broke TCP/ICMP to LAN peers (e.g. p620).
    # Note: flipping this flag in Nix does not rewrite tailscale's persisted
    # prefs; run `sudo tailscale set --accept-routes=false` once after switch.
    useRoutingFeatures = "none";
    openFirewall = true;
  };

  # Time sync. razer roams onto networks (e.g. corporate/guest WiFi) that
  # block public NTP on UDP 123, leaving the clock free-running and drifting.
  # timesyncd uses the public pool whenever the network allows NTP; the
  # httpTimeFallback below covers networks that block it.
  services.timesyncd = {
    enable = true;
    servers = [
      "0.pool.ntp.org"
      "1.pool.ntp.org"
      "2.pool.ntp.org"
    ];
  };

  # Fallback for networks that block NTP (UDP 123): when timesyncd has not
  # synchronised, htpdate sets the clock from HTTPS (443) — sampling several
  # servers with latency compensation. Only acts when NTP is unsynced, so it
  # never fights normal NTP discipline.
  services.httpTimeFallback.enable = true;

  # COSMIC Notifications NG - Disabled: removed from active config
  # services.cosmic-ext-notifications = {
  #   enable = true;
  #   settings.max_image_size = 32;
  # };

  # COSMIC BG - Disabled pending upstream fix for startup race condition
  # See: https://github.com/olafkfreund/cosmic-ext-bg/issues/32
  # services.cosmic-ext-bg.enable = true;

  # AI analysis services removed - were non-functional and consuming resources
  # ai.analysis = {
  #   enable = false;  # Removed completely - provided no meaningful analysis
  #   aiProvider = "openai";
  # };

  # NVIDIA GeForce NOW cloud gaming (official Flatpak)
  modules.services.geforcenow = {
    enable = true;
    autoInstall = true;
  };

  # Use the new features system instead of multiple lib.mkForce calls
  features = {
    virtualization.waydroid.disableGbm = true;

    cloud.azure = false;

  };

  features.flux = {
    # phone link, #2905
    enable = true;
    trustedConnections = [ "2480c26b-7797-49e1-8a9f-af6bccc6d77c" ]; # the home Wi-Fi
  };

  # GDM greeter visual baseline — dark colour scheme + 24h clock so it
  # doesn't render as a near-blank Adwaita-light surface over RDP.
  programs.dconf.profiles.gdm.databases = [{
    settings = {
      "org/gnome/desktop/interface" = {
        clock-format = "24h";
        color-scheme = "prefer-dark";
      };
    };
  }];

  # Disable system-mode GRD on razer. The GDM-greeter spawn path it uses
  # (`gdm-wayland-session: Unable to run session`) is broken on this host's
  # NVIDIA Optimus PRIME-sync hardware — verified by side-by-side journal
  # comparison with p510 (pure NVIDIA), where the same path succeeds. With
  # system-mode off, port 3389 frees up and the user-mode GRD daemon
  # binds it instead. User-mode requires a live olafkfreund session, so
  # the RDP flow is: physically log in once after each boot, then `razer:3389`
  # serves your desktop for the rest of that uptime.
  services.gnome.gnome-remote-desktop.enable = lib.mkForce false;
  systemd.services.grd-bootstrap.enable = lib.mkForce false;
  # The shared module unconditionally adds wantedBy=[graphical.target] to
  # gnome-remote-desktop.service; with the service body gone (line above),
  # that orphan wantedBy makes systemd reject the partial unit ("bad unit
  # file setting"). Clear it.
  systemd.services.gnome-remote-desktop.wantedBy = lib.mkForce [ ];

  # Auto-sync Chrome PWA icons into the XDG hicolor tree (issue #397).
  # Chrome stores PWA PNG files inside its profile dir, which no launcher indexes;
  # this module symlinks them where COSMIC/GNOME can find them.
  modules.programs.chrome-pwa-icons = {
    enable = true;
    user = vars.username;
  };

  # Nix build optimizations
  nix = {
    settings = {
      max-jobs = lib.mkDefault 16; # i7-10875H has 8 cores/16 threads
      cores = lib.mkDefault 16; # Use all threads
      # auto-optimise-store: see modules/nix/nix.nix -- it races the in-build
      # collector; nix.optimise runs the same deduplication on a timer.
    };
    extraOptions = ''
      keep-outputs = true
      keep-derivations = true
    '';
  };

  # Consolidated services configuration
  services = {

    # GNOME Remote Desktop configuration moved to features.gnome-remote-desktop

    # X server and desktop environment
    xserver = {
      videoDrivers = [ vars.gpu ];
    };

  };

  # Hardware and service specific configurations
  services = {
    # Quiet sshd preauth-reset spam from Odin's :22 liveness probes (p510).
    openssh.settings.LogLevel = "ERROR";
    nfs.server = lib.mkIf vars.services.nfs.enable {
      enable = true;
      inherit (vars.services.nfs) exports;
    };
  };

  # Docker configuration
  modules.containers.docker = {
    enable = true;
    users = hostUsers; # Use all users for this host
    rootless = false;
    # Preserves the path this host has always used. Unlike p510, /mnt/img_pool
    # here is a plain directory on the root filesystem, not a separate disk;
    # the value is legacy rather than deliberate, but repointing it would
    # orphan the existing data-root in place.
    dataRoot = "/mnt/img_pool/docker";
  };

  # Use DHCP-provided DNS servers
  # networking.nameservers = vars.nameservers; # Commented out to use DHCP

  # CRITICAL: DNS Resolution Fix for Tailscale
  # Network profile handles service ordering automatically

  # Use standard NetworkManager for laptop - useNetworkd already set above
  networking.useHostResolvConf = false;

  # Pin the other hosts to their Tailscale IPs so `p620.lan` / `p510.lan`
  # resolve even when the router's `.lan` mDNS/DNS is flaky — which broke a
  # `just deploy-via-p620 razer` (Could not resolve hostname p620.lan).
  # Tailscale is always up, so these names are always routable.
  networking.hosts = {
    "100.69.100.115" = [ "p620" "p620.lan" ];
    "100.118.96.32" = [ "p510" "p510.lan" ];
  };

  environment.sessionVariables = vars.environmentVariables // {
    NH_FLAKE = vars.paths.flakeDir;
  };

  users.users = lib.genAttrs hostUsers (username: {
    isNormalUser = true;
    description = "User ${username}";
    extraGroups = [
      "wheel"
      "networkmanager"
      "ydotool" # /run/ydotoold/socket access for the voice-input client
      "libvirtd" # read-write libvirt socket; without it virt-manager gets "access denied by policy"
    ];
    # Bash is the login shell (see modules/common/base-user.nix); zsh stays
    # installed as the rollback path.
    shell = pkgs.bashInteractive;
    # hc (herdr-core) keeps agents running after logout (#2861).
    linger = username == "olafkfreund";
  });

  # System packages - consolidated from individual nixos modules
  environment.systemPackages = (with pkgs.gst_all_1; [
    # GStreamer full plugin set — explicit system-level install so
    # gst-inspect-1.0 / gst-launch-1.0 and ad-hoc media tooling find
    # codecs reliably (GNOME pulls these in transitively but only
    # exposes them inside app wrappers, not on the system GST_PLUGIN_PATH).
    # Tracks nixpkgs-unstable's current GStreamer 1.26.x stable.
    #
    # NOTE: `gstreamer` itself has `meta.outputsToInstall = ["bin"]` —
    # the default add gives ONLY the gst-* CLI tools, NOT the core
    # plugins (coreelements: fakesink, identity, queue, tee, …). We must
    # explicitly add `gstreamer.out` to get libgstcoreelements.so onto
    # GST_PLUGIN_SYSTEM_PATH_1_0. Without it, anything using `fakesink`
    # (e.g. YetAnotherRadio's playbin3 video-sink stub) fails with
    # "GStreamer plugin missing".
    gstreamer
    gstreamer.out
    gst-plugins-base
    gst-plugins-good
    gst-plugins-bad
    gst-plugins-ugly
    gst-libav
    # gst-plugin-pipewire is NOT in gst_all_1 — the PipeWire GStreamer
    # plugin ships inside the pipewire package itself (libgstpipewire.so
    # under pipewire's lib output). The active services.pipewire wires it.
    # gst-vaapi removed in GStreamer 1.28 — VA-API now lives in the `va`
    # plugin inside gst-plugins-bad (already installed above).
    gst-plugins-rs
  ]) ++ (with pkgs;
    [
      # Qt theme control tools for Stylix
      libsForQt5.qt5ct
      kdePackages.qt6ct
      # Custom packages
      # qwen-code disabled due to npm registry network errors (HTTP/2 framing layer issue)
      # (callPackage ../../home/development/qwen-code/default.nix { })
      nix-doc # Interactive Nix documentation tool
      customPkgs.rmux # Rust tmux-compatible multiplexer + typed SDK for agent orchestration
      # Remote desktop
      rustdesk-flutter
      # Messaging applications
      karere # GTK4 WhatsApp client

      # Power management (from power.nix)
      cpupower-gui # GUI for CPU frequency scaling
      powertop # Power consumption analyzer
      lm_sensors # Hardware monitoring
      s-tui # Terminal UI stress test and monitoring tool
      htop # Process viewer with power info
      acpi # Command line battery info

      # Razer hardware support (from laptop.nix)
      polychromatic # GUI for Razer devices
      razergenie # Another Razer configuration tool

      # Bluetooth earbuds. Backs the io.github.rdoupe.pixelbuds Omarchy bar
      # plugin, which shells out to `pbpctrl` for battery, noise-cancelling
      # mode and EQ.
      #
      # Note this does NOT work with the Pixel Buds A-Series paired here:
      # pbpctrl drives Google's "maestro" RFCOMM profile, which the A-Series
      # does not advertise (only Audio Sink and AVRCP), so every command
      # fails with br-connection-profile-unavailable. Upstream issue
      # qzed/pbpctrl "Doesn't work on A-Series" has been open since 2023.
      # Installed deliberately anyway, ready for Pixel Buds Pro hardware.
      pbpctrl # Pixel Buds Pro control (battery, noise-cancelling, EQ)

      # Secure Boot management (from secure-boot.nix) - only when secure boot enabled
    ]
    ++ lib.optionals (config.boot.lanzaboote.enable or false) [
      sbctl # For managing Secure Boot keys
    ]
    # Every DE registered via services.xserver.desktopManager.*.enable —
    # needed so their share/wayland-sessions/*.desktop files land in
    # /run/current-system/sw/share/wayland-sessions where COSMIC Greeter
    # (and other display managers) actually look for session choices.
    ++ config.services.displayManager.sessionPackages);

  hardware.nvidia-container-toolkit.enable = vars.gpu == "nvidia";

  # Enable ZSA keyboard support (Moonlander, Planck EZ, etc.)
  hardware.keyboard.zsa.enable = true;

  # Windows app integration
  # programs.winboat.enable = true; # DISABLED: npm dependency error in nixpkgs (@electron/windows-sign)

  age.secrets.nix-signing-key = {
    file = ../../secrets/nix-signing-key-razer.age;
    owner = "root";
    mode = "0400";
  };
  nix.settings.secret-key-files = config.age.secrets.nix-signing-key.path;

  # Agenix identity configuration - specify where to find decryption keys
  age.identityPaths = [
    "/home/olafkfreund/.ssh/id_ed25519" # User key
    "/etc/ssh/ssh_host_ed25519_key" # Host key (Ed25519)
    "/etc/ssh/ssh_host_rsa_key" # Host key (RSA fallback)
  ];

  # User group membership for /run/ydotoold/socket access is added in the
  # `users.users = lib.genAttrs hostUsers ...` block above.

  # Meeting transcribe — razer is client-only. Records the meeting locally,
  # then rsyncs the .opus over Tailscale to p620 and SSHes to run
  # meet-process there. The brief comes back as ~/meetings/TS.md.
  features.meetingTranscribe = {
    enable = true;
    processHost = "p620";
    installProcessor = false;
    userName = "Olaf";
    userEmail = "olaf@freundcloud.com";
  };

  nixpkgs.config = {
    allowBroken = true;
    permittedInsecurePackages = [
      "olm-3.2.16"
      "python3.12-youtube-dl-2021.12.17"
      "python3.13-youtube-dl-2021.12.17" # newsboat (RSS reader) pulls youtube-dl for URL extraction
      "libsoup-2.74.3" # Temporary: Required by some GNOME packages until migration to libsoup-3
    ];
  };

  # ── RDP client, for connecting OUT to the other machines ────────────────
  #
  # For RDP servers elsewhere: our own hosts no longer serve RDP (nixarchy
  # removed hypr-rdp, #2510); between them use gliff. The package ships
  # xfreerdp, wlfreerdp and sdl-freerdp; `nixarchy remote connect` launches
  # sdl-freerdp, because upstream deprecated its Wayland client in the SDL3
  # client's favour and SDL3 needs no Xwayland hop.
  #
  # Reach it from Setup > Remote desktop > Connect to a machine, which
  # forwards a free local port over SSH and opens no port anywhere.
  programs.nixarchy.apps.freerdp.enable = true;

  # Haiku writes summaries here; the ElevenLabs key comes from agenix.
  features.agentVoice.summary.backend = "claude";
}
