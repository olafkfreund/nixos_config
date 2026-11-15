{ config, username, ... }:
{
  secrets.apiKeys.braveSearch = true;
  modules = {
    security.secrets.enable = true;
    hardware.ddcutil.enable = true;
    programs = {
      # Read-only managed-settings baseline in /etc/claude-code (#398). User
      # ~/.claude/settings.json stays writable for plugins and runtime changes.
      claude-code-managed = {
        enable = true;
        parrProtocol.enable = false;
        # tmux-ccm handles notifications, so the unthrottled hooks stay off.
        notifications.enable = false;
        subagentMetadata.codex = true;
      };
      claude-code-mods.enable = true;
      # /use-ollama, /use-claude, /use-default + an apiKeyHelper that picks the
      # router or the Anthropic key from ANTHROPIC_BASE_URL.
      claude-router-cli.enable = true;
    };
  };

  features = {
    development = {
      enable = true;
      cargo = true;
      copilot-cli = true;
      spec-kit = true;
      github = true;
      go = true;
      java = true;
      lua = true;
      nix = true;
      shell = true;
      devshell = true;
      python = true;
      nodejs = true;
    };
    virtualization = {
      enable = true;
      docker = true;
      incus = false;
      podman = true;
      spice = true;
      libvirt = true;
      waydroid = {
        enable = true;
        enableWaydroidHelper = true;
      };
    };
    cloud = {
      enable = true;
      aws = true;
      google = true;
      k8s = true;
      terraform = true;
    };
    ai.mcp = {
      enable = true;
      # The package is supplied by the desktop user profile on these two hosts.
      # Authentication remains an interactive `nlm auth` step.
      notebooklm.enable = true;
      obsidian = {
        enable = true;
        implementation = "rest-api";
        restApi.apiKeyFile = config.age.secrets."obsidian-api-key".path;
      };
      # Off until the secret exists (docs/LINKEDIN-MCP.md):
      #   ./scripts/manage-secrets.sh create api-linkedin-cookie
      linkedin = {
        enable = false;
        cookieFile = config.age.secrets."api-linkedin-cookie".path;
      };
      whatsapp = {
        enable = false;
        enableVoiceMessages = false;
      };
      servers = {
        browsermcp = true;
        terraform = true;
      };
    };
    programs = {
      lazygit = true;
      thunderbird = false;
      obsidian = true;
      office = true;
      webcam = true;
      print = true;
    };
    claude-hooks = {
      enable = true;
      enablePermissionNotifications = true;
      enableReadyNotifications = true;
    };
    # COSMIC parked (modules/desktop/cosmic.nix, pkgs/cosmic-applets/) until it
    # is production-ready.
    desktop.cosmic.enable = false;
    intune = {
      enable = false;
      autoStart = false;
      enableDesktopIntegration = true;
    };
    themeOwner.enable = true;
    craftapps = {
      enable = true;
      apps = {
        cadcraft = true;
        deckcraft = true;
        designcraft = true;
        effectcraft = true;
        filmcraft = true;
        gridcraft = true;
        lightcraft = true;
        pdfcraft = true;
        photocraft = true;
        soundcraft = true;
        vectorcraft = true;
        wordcraft = true;
      };
    };
    tfm = {
      enable = true;
      settings.ui."preview-enabled" = true;
    };
    claudeSwarmReaper = { enable = true; dryRun = false; };
    agentVoice = {
      enable = true;
      speaker = "nixi";
      voice.elevenLabsKeyFile = config.age.secrets."api-elevenlabs".path;
    };
  };

  services = {
    # Off. Module, overlay and package are kept, but the requireFile tarball
    # was deleted: re-enabling needs pkgs/citrix-workspace/fetch-citrix.sh first.
    citrix-workspace = {
      enable = false;
      acceptLicense = true;
    };
    rescreenshot-mcp = {
      enable = true;
      user = username;
      logLevel = "info";
      autoConfigureClaudeDesktop = true;
    };
    playerctld.enable = true;
    fwupd.enable = true;
  };
  # playerctl can segfault on player signals; restart its user unit.
  systemd.user.services.playerctld.serviceConfig.Restart = "on-failure";
  # ydotoold: keystroke injection for the voice-input client on GNOME Wayland,
  # where wtype fails (Mutter has no virtual_keyboard_v1). It does not add users
  # to the ydotool group; each host does that in its users.users block.
  programs.ydotool.enable = true;
}
