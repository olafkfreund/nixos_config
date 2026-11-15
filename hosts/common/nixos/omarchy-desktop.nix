{ inputs, lib, pkgs, ... }:
{
  programs = {
    nixarchy = {
      enable = true;
      # Omarchy's own apps: Hype, Monologue, Signed, Disktree and the rest (nixarchy#1572).
      omarchyApps.enable = true;
      # Puts this user in the input group; Omarchy's shell reads the keyboard
      # device directly, and without it the session never sees a keypress.
      user = "olafkfreund";
      # Unused preinstalls (#2133); screen recording is Omareel.
      preinstallsExclude = [ "obs-studio" "kdenlive" ];
      # Tints Chromium-family browsers with the theme accent. The cost: Chromium
      # reads policy only from /etc/<browser>/policies/managed, so this hands
      # those directories to this user, and any process running as olafkfreund
      # (agents with shell access included) can set machine-wide browser policy,
      # forced extensions and proxies too. Deliberately not on p510, which is why
      # p510 does not import this file.
      browserThemeUser = "olafkfreund";
      # Omarchy's SDDM greeter is the login manager (replaced the DMS greetd
      # greeter); GNOME stays selectable alongside the Omarchy session.
      displayManager = true;
      # Forces boot.plymouth.theme and themePackages together; forcing the name
      # alone fails the build on a theme missing from the package list.
      bootSplash = "force";
    };
    # nixarchy pins its own Hyprland; nixpkgs sets portalPackage at mkDefault,
    # so matching it would tie rather than yield, hence the force. No .package
    # force: omarchy-sole-hyprland.nix turns programs.hyprland off outright.
    hyprland.portalPackage = lib.mkForce pkgs.xdg-desktop-portal-hyprland;
  };

  home-manager.users.olafkfreund = {
    programs.nixarchy = {
      enable = true;
      # Stock Omarchy menu (#2325): nixarchy turns nixarchy-menu on by default.
      defaultPlugins.menu = false;
      # Installed, not enabled: enabling is runtime state in shell.json, so once
      # per machine run `omarchy plugin enable nixarchy.pkg` (and .distrobox).
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
