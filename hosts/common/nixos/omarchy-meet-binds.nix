# Meeting recording keybinding for the Omarchy session.
#
# The `meet` CLI has always been installed by
# modules/services/meeting-transcribe.nix, but its one-button promise
# (SUPER+SHIFT+M) was wired only in home/desktop/gnome/keybindings.nix. Every
# host defaults to the Omarchy session, where nothing was bound at all, so the
# feature was CLI-only on the desktop it actually runs on.
#
# Guarded on the feature rather than on the host list: p510 imports the
# nixarchy stack too but does not enable meetingTranscribe, and binding a key
# to a binary that isn't in PATH just fails silently at press time.
#
# Same lua-fragment pattern, and the same pcall caveat, as omarchy-gog.nix:
# bindings.lua is user-owned and outlives any generation that stops providing
# this file, so it must load it with
#   pcall(require, "hypr.meet-binds")
# A bare require of a missing file fails the WHOLE Hyprland config and drops
# the session into the error overlay.
{ config, lib, ... }:
let
  # attrByPath, not config.features.meetingTranscribe.enable: p510 imports the
  # nixarchy stack but never imports modules/services/meeting-transcribe.nix,
  # so the option is not merely false there -- it does not exist, and a direct
  # reference throws "attribute 'meetingTranscribe' missing" at eval.
  enabled = lib.attrByPath [ "features" "meetingTranscribe" "enable" ] false config;
in
{
  config = lib.mkIf enabled {
    home-manager.users.olafkfreund.home.file.".config/hypr/meet-binds.lua".text = ''
      -- Managed by hosts/common/nixos/omarchy-meet-binds.nix -- edits here are
      -- overwritten on the next deploy.

      -- Matches the GNOME binding (custom5) so the key is the same whichever
      -- session is running. First press starts recording mic + system audio,
      -- second stops it and dispatches the whisperX/Ollama pipeline.
      o.bind("SUPER + SHIFT + M", "Meeting record/transcribe/summarize", "meet toggle")
    '';
  };
}
