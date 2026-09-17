# Anything at all.
#
# apps.nix is a list nixarchy generated and services.nix is a catalogue it
# curated. This file has neither, because at some point the answer to "how
# do I do X on NixOS" is a NixOS option nobody put on a list, and a curated
# desktop that has no room for that is a cage.
#
# It is an ordinary NixOS module. Every option in nixpkgs is available:
#
#   services.openssh.settings.PermitRootLogin = "no";
#   boot.kernelParams = [ "quiet" ];
#   users.users.you.extraGroups = [ "dialout" ];
#
# `nixarchy-search` writes here when you pick an option from it. Nothing
# else touches this file.
#
# If you find yourself writing the same thing here on every machine, that
# is worth an issue -- it probably belongs in the catalogue.
{ ... }:
{
}
