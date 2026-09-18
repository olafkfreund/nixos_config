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


  # ── Added by nixarchy-catalogue-diff, 2026-09-17 ──
    # programs.nixarchy.services.devenv.enable = true;  #@ devenv  # Per-project development environments that activate when you cd in. Bundled because it is a package plus an activation hook in each of bash, zsh and fish, and a cache to keep the first use from being a compile.
    # programs.nixarchy.flatpaks.apps.geforce-now.enable = true;  #@ geforce-now  # Streams games from NVIDIA's servers. Not in nixpkgs and not packageable: a proprietary binary NVIDIA ships as a Flatpak. Not on Flathub either -- it comes from NVIDIA's own repository, which enabling this adds. — from GeForceNOW, not Flathub
    # programs.nixarchy.services.hypr-rdp.enable = true;  #@ hypr-rdp  # Serve your running Hyprland session to any RDP client. Bundled because the password must come from an encrypted secret, the daemon needs your session, and the firewall stays closed unless you say otherwise. Reachable over your tailnet by default, not your LAN.
    # programs.nixarchy.services.microvm.enable = true;  #@ microvm  # Permanent NixOS sandboxes from a template, booted with no image build and no bootloader -- the host's own /nix/store, shared read-only. Bundled because declaring a machine is what turns on the system user, the kvm group grant, the kernel modules and the microvm CLI; a machine you never declare gets none of them.
    # programs.nixarchy.services.open-webui.enable = true;  #@ open-webui  # A browser chat window over the models this machine already runs. Needs an Ollama -- programs.nixarchy.localAi.enable is the one that puts a model on the machine -- and refuses to build without one rather than showing you an empty model list. Stays on loopback: the first visitor to reach it becomes the administrator, so open the firewall only after you have logged in once.
    # programs.nixarchy.services.tailscale.enable = true;  #@ tailscale  # A private network between your machines. Bundled because the firewall has to trust the interface or nothing reaches this host.
    # virtualisation.waydroid.enable = true;  #@ waydroid  # Android apps in a container on your own kernel. No CPU emulation, so it is fast -- and ARM-only apps will not run without a translation layer (libhoudini/libndk) that Waydroid does not ship and nixpkgs does not package. Needs the binder kernel module, which mainline has and a custom kernel may not, and ships without the Play Store. For apps that refuse to run in a container at all, scrcpy mirrors a real phone instead.
}
