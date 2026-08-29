# Google Workspace integration for the Omarchy session, shared by p620 and
# razer. The commands themselves come from home/shell/gogcli; this file is only
# the desktop surfaces for them: menu rows and a keybinding.
#
# The menu jsonc is generated into the store and is not editable in ~/.config,
# so rows have to be declared. The keybinding rides in its own lua file for the
# same reason bindings.lua does not: bindings.lua is where Omarchy expects
# personal edits and stays user-owned, so it keeps the one hand-written line
#   pcall(require, "hypr.gog-binds")
# while everything it loads is managed here.
#
# pcall, not a bare require. bindings.lua is user-owned and survives deploys
# untouched, so it outlives any generation that stops providing gog-binds.lua
# -- a rollback, a host that never imported this module, a branch cut before
# it existed. A bare require of a missing file does not skip those binds, it
# fails the WHOLE Hyprland config and drops the session into the error
# overlay. That happened on razer: a rollback removed the file, bindings.lua
# still demanded it, and the desktop came up unusable with nothing in the
# config naming the cause.
{ ... }:
{
  programs.nixarchy.menu.extraEntries = {
    "capture.note" = {
      icon = "";
      label = "Quick Note";
      action = "omarchy-cmd-note";
    };
    "capture.upload" = {
      icon = "";
      label = "Upload to Drive";
      action = "omarchy-cmd-upload";
    };
    "capture.meet" = {
      icon = "";
      label = "New Meet";
      action = "omarchy-cmd-meet";
    };
  };

  home-manager.users.olafkfreund.home.file.".config/hypr/gog-binds.lua".text = ''
    -- Managed by hosts/common/nixos/omarchy-gog.nix -- edits here are
    -- overwritten on the next deploy.

    -- SUPER+SHIFT+M would read better, but it is already bound; V is free and
    -- reads as "video call". The command copies the link before opening the
    -- browser, so the link survives the browser failing to launch.
    o.bind("SUPER + SHIFT + V", "New Google Meet (link copied)", "omarchy-cmd-meet")
  '';
}
