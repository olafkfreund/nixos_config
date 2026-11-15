{ config, username, ... }:
{
  secrets.apiKeys.braveSearch = true;
  modules = {
    security.secrets.enable = true;
    hardware.ddcutil.enable = true;
    programs = {
      claude-code-managed = {
        enable = true;
        parrProtocol.enable = false;
        # tmux-ccm handles notifications, so the unthrottled hooks stay off.
        notifications.enable = false;
        subagentMetadata.codex = true;
      };
      claude-code-mods.enable = true;
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
  programs.ydotool.enable = true;
}
