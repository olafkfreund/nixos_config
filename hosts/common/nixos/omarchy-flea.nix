# Flea: the Omarchy file manager (thisisgm/flea), from the nixarchy-flea flake
# (upstream's prebuilt binaries in an FHS runtime). The NixOS module registers Flea's
# portal file chooser backend and its FileManager1 D-Bus service, and turns on
# gvfs/udisks2/usbmuxd (mkDefault). The Home Manager part makes Flea the folder
# default, the portal file picker and the Super+Shift+F / Super+Alt+Shift+F app.
#
# One step per machine that a rebuild cannot do, because the file is user-owned
# (same caveat as omarchy-ai-mirror.nix):
#   append at the END of ~/.config/hypr/bindings.lua:  pcall(require, "hypr.flea-binds")
#   It must come after Omarchy's default binds (hyprland.lua loads those first) so
#   Flea's hl.unbind replaces Nautilus's keys. pcall makes it safe before the deploy.
#
# The first switch backs up the old mutable ~/.config/xdg-desktop-portal/hyprland-portals.conf
# to ~/.hm-backups/<timestamp>/ (home-manager.backupCommand in flake.nix). After a
# rollback, restore it from there: it carries the Secret=gnome-keyring line.
#
# Never use `flea --default`, `flea --picker` or Flea's Settings > About switch here:
# Home Manager owns the files they would edit.
{ inputs, lib, ... }:
{
  imports = [ inputs.nixarchy-flea.nixosModules.flea ];

  programs.flea = {
    enable = true;
    optionalDependencies = {
      ffmpegthumbnailer = true;
      sevenzip = true;
      imagemagick = true;
      zoxide = true;
    };
  };

  home-manager.users.olafkfreund = {
    imports = [ inputs.nixarchy-flea.homeManagerModules.flea ];
    programs.flea = {
      enable = true;
      defaultFileManager.enable = true;
      filePicker = {
        enable = true;
        # The lines the mutable hyprland-portals.conf held before Flea took the file over.
        extraConfig = {
          default = "hyprland;gtk";
          "org.freedesktop.impl.portal.Secret" = "gnome-keyring";
        };
      };
      hyprland.bindings.enable = true;
    };
    # home/desktop/gnome/default.nix sets Nautilus at normal priority, and mimeApps
    # lists merge, so the result would be both, in an unspecified order.
    xdg.mimeApps.defaultApplications."inode/directory" = lib.mkForce [ "com.thisisgm.flea.desktop" ];
  };
}
