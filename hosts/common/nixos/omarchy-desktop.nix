{ inputs, lib, pkgs, ... }:
{
  programs = {
    nixarchy = {
      enable = true;
      omarchyApps.enable = true;
      user = "olafkfreund";
      preinstallsExclude = [ "obs-studio" "kdenlive" ];
      # Browser policy is system-wide, so this is limited to these single-user desktops.
      browserThemeUser = "olafkfreund";
      # SDDM offers Omarchy and GNOME; Omarchy supplies the boot splash.
      displayManager = true;
      bootSplash = "force";
    };
    # Nixpkgs sets its portal at mkDefault; the Nixarchy portal must win.
    hyprland.portalPackage = lib.mkForce pkgs.xdg-desktop-portal-hyprland;
  };

  home-manager.users.olafkfreund = {
    programs.nixarchy = {
      enable = true;
      defaultPlugins.menu = false;
      plugins = {
        "nixarchy.pkg".src = inputs.nixarchy-pkg.packages.${pkgs.stdenv.hostPlatform.system}.default;
        "nixarchy.distrobox".src = inputs.nixarchy-distrobox.packages.${pkgs.stdenv.hostPlatform.system}.default;
      };
    };
    # Installed examples remain disabled until enabled in the shell.
    services.nixi.companion.plugins =
      with inputs.nixi-companion.legacyPackages.${pkgs.stdenv.hostPlatform.system}.examples; [
        pirate-quips
        element-chat
        party-hat-plus
      ];
  };
}
