{ inputs
, lib
, pkgs
, ...
}:
# Omarchy, vendored for NixOS. Same shape as p620 and razer.
#
# This file used to say the opposite of everything below it. p510 was class
# headless-rdp: GDM autologged into GNOME, gnome-remote-desktop served that
# session over RDP, and Omarchy was added as a selectable entry that nothing
# could ever select -- SDDM off so the RDP path kept its display manager,
# defaultSession pinned to gnome so autologin did not wander off into
# Hyprland. It worked exactly as designed, which is to say the session was
# installed and never once started: seven days of journal held no
# start-hyprland, no wayland-wm@, no omarchy-launch-shell, and ~/.config/hypr
# did not exist.
#
# The machine has a monitor now and is going to be used, so the three settings
# that held Omarchy at arm's length are inverted and this host joins the
# template the other two share. What that costs is written down under
# "Divergences" at the bottom, because two of the reasons for the old
# arrangement are still true.
{
  imports = [
    inputs.nixarchy.nixosModules.nixarchy
    ../../../nixarchy-apps.nix
    ../../common/nixos/omarchy-input.nix
    ../../common/nixos/omarchy-sddm.nix
    ../../common/nixos/omarchy-workspaces.nix
    ../../common/nixos/omarchy-gog.nix
    ../../common/nixos/omarchy-meet-binds.nix
    ../../common/nixos/omarchy-sole-hyprland.nix
    ../../common/nixos/omarchy-stylix-theme.nix
  ];

  programs.nixarchy.enable = true;

  # Puts this user in the input group. Omarchy's shell reads the keyboard
  # device directly for its own key handling, which the group grants; without
  # it the session starts but never sees a keypress.
  programs.nixarchy.user = "olafkfreund";

  # nixarchy pins its own Hyprland and does not defer -- nixpkgs defines
  # programs.hyprland.portalPackage at mkDefault priority, so matching it would
  # tie rather than yield, hence the force.
  programs.hyprland.portalPackage = lib.mkForce pkgs.xdg-desktop-portal-hyprland;

  # Omarchy's SDDM greeter is the login manager, replacing GDM. This is the
  # setting the old comment argued hardest against, and the argument was sound
  # while RDP was the only way in: flipping it swaps the display manager on a
  # machine with no monitor attached. There is a monitor now, and Sunshine
  # (features.sunshine, modules/desktop/sunshine.nix) is what serves the
  # session remotely, so GDM is no longer load-bearing.
  #
  # SDDM enumerates wayland-sessions, so GNOME stays selectable next to
  # Omarchy -- nothing is removed from the login menu, the default just moves.
  programs.nixarchy.displayManager = true;

  # Boot to Omarchy's splash. The option forces boot.plymouth.theme and
  # themePackages together on purpose: forcing the name alone leaves NixOS
  # asserting a theme that is not in the package list, which fails the build.
  #
  # "force" rather than "defer" for the same reason as the other two hosts --
  # this fleet's stylix names a theme of its own, and defer would yield to it.
  programs.nixarchy.bootSplash = "force";

  # ── Divergences from p620 and razer ──────────────────────────────────────
  #
  # preinstalls stays off. Omarchy's application bundle measured 50.52 -> 57.56
  # GiB of closure when it was tried here, and cef-binary alone is 1.9 GiB. The
  # root filesystem holding /nix is 226 GB at 80% -- 47 GB free -- so this is
  # the one part of the template that is not a one-line copy, and turning it on
  # is a disk decision rather than a desktop one. Nothing about the session
  # needs it: alacritty, ghostty, kitty and foot are all already on this host
  # from our own modules, so Omarchy's terminal bindings work as shipped.
  #
  #   programs.nixarchy.preinstalls = true;   # <- when there is room
  #
  # Autologin stays ON, where p620 sets nothing and razer deliberately turns it
  # off. Sunshine is a systemd *user* service, so it exists only inside a live
  # graphical session; this machine reboots unattended and serves media, and an
  # unattended reboot that lands on a greeter is an unattended reboot with no
  # remote desktop until someone walks to it. razer's reason for the opposite
  # choice does not apply here -- that is Optimus PRIME-sync hardware where
  # greeter respawn is broken, and this host is pure NVIDIA.
  #
  # RDP is not removed, but it changes character. features.gnome-remote-desktop
  # stays enabled and its system daemon serves a GNOME session; with GDM gone
  # that daemon loses the remote-login path it had here and behaves the way it
  # does on razer -- user-mode, tied to a live GNOME session. So RDP into a
  # fresh GNOME desktop is what this change gives up, and Sunshine into the
  # Omarchy session is what replaces it. Log into GNOME at SDDM and RDP works
  # as before.
  programs.nixarchy.preinstalls = false;

  home-manager.users.olafkfreund = {
    imports = [ inputs.nixarchy.homeManagerModules.nixarchy ];
    programs.nixarchy.enable = true;
  };
}
