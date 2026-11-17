# Omateams: Microsoft Teams web in an Omarchy-themed window (#2505, #3028),
# from our fork's flake. Its home-manager module installs it and registers
# the plugin; the plugin is enabled once per host by the shared post-boot
# hook. Sign in to Teams once per host: the login lives in
# ~/.local/share/omateams and stays yours.
# Update with `nix flake update omateams`, never `omarchy plugin update`.
{ config, inputs, pkgs, ... }:
let
  # The fork's package, with the host's Hyprland tools on its PATH.
  omateams = inputs.omateams.packages.${pkgs.stdenv.hostPlatform.system}.omateams.override {
    hyprland = config.programs.hyprland.package;
  };
in
{
  imports = [ ./omarchy-enable-once.nix ];

  home-manager.users.olafkfreund = {
    imports = [ inputs.omateams.homeManagerModules.default ];
    programs.omateams = {
      enable = true;
      package = omateams;
    };
    local.omarchy.enableOnce = [ "omateams" ];
  };
}
