{ lib, ... }:
let inherit (lib) mkOption types;
in {
  options.desktop.gnome.profile = mkOption {
    type = types.enum [ "workstation" "laptop" "headless" ];
    default = "workstation";
    description = ''
      User-environment role. Drives extension subset and battery
      extensions. Mirrors the system-level host.class enum but lives
      at the home-manager level for HM-only concerns (extension picks,
      battery indicators, etc.).

      - workstation: AC-only, adds vitals + blur-my-shell
      - laptop:      battery-aware, adds battery-health-charging + caffeine + clipboard-indicator
      - headless:    no GNOME desktop enabled at all
    '';
  };
}
