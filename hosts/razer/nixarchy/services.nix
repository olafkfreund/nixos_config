# Services and system settings, as NixOS configuration.
#
# The companion to apps.nix. An app is a package; a service is a decision
# about the machine. Uncomment what you want -- or pick it from the menu --
# then run
#
#     nixarchy-apply
#
# Two kinds of line appear below and the difference is deliberate:
#
#   programs.nixarchy.services.X   nixarchy bundles several options here,
#                                  because turning the thing on usefully
#                                  takes more than one.
#
#   services.X.enable              the real NixOS option, because there was
#                                  nothing for nixarchy to add. This is the
#                                  line every wiki page will show you, and
#                                  it is the same line here.
#
# This file is a NixOS module and nothing stops you writing any option in
# it. Upstream's own settings work alongside ours -- if you enable
# syncthing below, `services.syncthing.settings.folders` still does what
# its documentation says.
#
# This file is yours. Nothing regenerates or overwrites it once created;
# the current full list is always at /etc/nixarchy/services-template.nix.
{ ... }:
{
    # ── Desktop ──────────────────────────────────────
    # services.flatpak.enable = true;  #@ flatpak  # For software nixpkgs does not carry. Then: flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    # programs.nixarchy.services.syncthing.enable = true;  #@ syncthing  # Syncs folders between your machines. Bundled because it runs as you, and upstream cannot know which user that is.

    # ── Hardware ──────────────────────────────────────
    # hardware.graphics.enable32Bit = true;  #@ graphics32  # Wanted by Steam, Wine and older games. One switch covers every driver.

    # ── Network ──────────────────────────────────────
    # services.openssh.enable = true;  #@ openssh  # Remote login. Opens port 22 and NixOS defaults to keys only, not passwords.

}
