# nixarchy-microvm: NixOS MicroVMs in the Omarchy shell -- a bar glyph, and a
# full-screen keyboard menu on SUPER + ALT + V that lists, starts, stops,
# creates, edits and deletes both disposable (`nixarchy vm`) and permanent
# (programs.nixarchy.services.microvm) VMs.
#
# The module registers the plugin through programs.nixarchy.plugins (validated
# at build) and imports the plugin's own Home Manager module, which writes
# ~/.config/hypr/microvm-binds.lua from the chord the plugin ships. One place
# for both, the same shape as omarchy-ai-mirror.nix.
#
# Two one-time steps per machine that a rebuild cannot do, because both files
# are user-owned (same caveat as omarchy-gog.nix / omarchy-meet-binds.nix):
#   1. add to ~/.config/hypr/bindings.lua:  pcall(require, "hypr.microvm-binds")
#      A bare require of a missing file fails the WHOLE Hyprland config.
#   2. omarchy plugin enable nixarchy.microvm
#      (nixarchy installs plugins but leaves enabling to the shell config).
{ inputs, ... }:
{
  home-manager.users.olafkfreund =
    { pkgs, ... }:
    {
      imports = [ inputs.nixarchy-microvm.homeManagerModules.default ];
      programs.nixarchy.plugins."nixarchy.microvm".src =
        inputs.nixarchy-microvm.packages.${pkgs.stdenv.hostPlatform.system}.default;
      # programs.nixarchy-microvm.keybinding defaults to "SUPER + ALT + V",
      # free on p620 and razer (checked with hyprctl binds -j). null writes
      # no bind.
    };
}
