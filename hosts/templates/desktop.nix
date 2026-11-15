{ profile ? "workstation" }:
{ lib, ... }:
{
  imports = [
    ../common/nixos/i18n.nix
    ../common/nixos/envvar.nix
    ../common/nixos/host-class.nix
    ../common/nixos/zfs-import.nix
    ../common/nixos/inotify-limits.nix
    ../../modules/core.nix
    ../../modules/development.nix
    ../../modules/desktop.nix
    ../../modules/virtualization.nix
    ../../modules/performance.nix
    ../../modules/email.nix
    ../../modules/cloud.nix
    ../../modules/programs.nix
    ../../modules/common/ai-defaults.nix
    ../../modules/windows/winboat.nix
  ];

  config = lib.mkMerge [
    {
      aiDefaults.enable = lib.mkDefault true;
      features.security = {
        enable = lib.mkDefault true;
        onepassword = lib.mkDefault true;
        gnupg = lib.mkDefault true;
      };
      features.syncthing = {
        enable = lib.mkDefault true;
        syncClaude = lib.mkDefault true;
        syncGemini = lib.mkDefault true;
      };
      features.gnome-remote-desktop.enable = lib.mkDefault true;
      # backend = "none" keeps GDM off. Omarchy's SDDM greeter is switched on by
      # programs.nixarchy.displayManager in each host's nixos/nixarchy.nix, and
      # enumerates wayland-sessions, so Omarchy and GNOME both stay selectable.
      # defaultSession is a fallback only: SDDM remembers the last session in
      # /var/lib/sddm/state.conf and that wins after the first login.
      desktop.displayManager.backend = lib.mkDefault "none";
      services.displayManager.defaultSession = lib.mkDefault "omarchy";
      services.desktopManager.gnome.enable = lib.mkDefault true;
      system.stateVersion = lib.mkDefault "25.11";
      services.xserver.enable = lib.mkDefault true;
      services.xserver.displayManager.xserverArgs = [
        "-nolisten tcp"
        "-dpi 96"
      ];
      secrets.apiKeys.enable = lib.mkDefault true;
      secrets.apiKeys.enableUserEnvironment = lib.mkDefault true;
      features.ai.enable = lib.mkDefault true;
      features.ai.antigravity-cli = lib.mkDefault true;
      features.ai.claude-desktop = lib.mkDefault true;
      features.media.droidcam = lib.mkDefault false;
      services.openssh.enable = lib.mkDefault true;
    }
    (lib.mkIf (profile == "laptop") {
      services.thermald.enable = lib.mkDefault true;
      powerManagement = {
        enable = lib.mkDefault true;
        cpuFreqGovernor = lib.mkDefault "powersave";
      };
    })
  ];
}
