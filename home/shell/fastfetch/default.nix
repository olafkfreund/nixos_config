# fastfetch — Omarchy's own readout.
#
# The config is read from the pinned omarchy source, with nixarchy's one
# branding patch (pkgs/omarchy/default.nix:659 in nixarchy) reapplied here.
# If nixarchy adds another patch to this file, mirror it here. The file is
# strict JSON despite the .jsonc name, so fromJSON reads it directly.
#
# The source is reached through inputs.nixarchy, never a literal store path.
#
# Its logo comes from ~/.config/omarchy/branding/about.txt, which Omarchy owns
# and retints with the theme -- nothing to declare here.
#
# This replaced a hand-built "Alien HUD" readout (git history, or
# /tmp/fastfetch-hud.nix.bak on p620 at the time of the swap). Three things went
# with it and are worth knowing if it is ever missed: a stylix-derived colour
# scheme, a boxed panel layout, and a pre-rendered ANSI logo that existed
# because fastfetch's runtime chafa logo needs the terminal's pixel-per-cell
# size and that query fails under tmux and herdr, silently falling back to the
# stock NixOS logo. Omarchy's config uses a plain text logo, so that trap does
# not apply to it.
{ pkgs, lib, inputs, ... }:
let
  src = builtins.readFile "${inputs.nixarchy.inputs.omarchy}/etc/fastfetch/config.jsonc";
  old = ''version=$(omarchy-version) && echo \"Omarchy $version\"'';
  new = ''version=$(omarchy-version) && echo \"Nixarchy (Omarchy $version)\"'';

  # Standalone `tracker` command -- the animated motion tracker on its own,
  # unrelated to the fastfetch config, so the branding swap does not remove it.
  trackerGif = ../../../assets/logos/motion-tracker.gif;
  trackerAnim = pkgs.writeShellScriptBin "tracker" ''
    exec ${pkgs.chafa}/bin/chafa --symbols sextant --colors full \
         --size 40x20 --duration "''${1:-inf}" ${trackerGif}
  '';
in
{
  home.packages = [ trackerAnim ];

  programs.fastfetch = {
    enable = true;
    settings =
      assert lib.assertMsg (lib.hasInfix old src)
        "omarchy fastfetch config changed; update the Nixarchy patch (#2930)";
      builtins.fromJSON (lib.replaceStrings [ old ] [ new ] src);
  };
}
