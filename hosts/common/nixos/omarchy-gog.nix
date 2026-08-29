# Google Workspace integration for the Omarchy session, shared by p620 and
# razer. The commands themselves come from home/shell/gogcli; this file is only
# the desktop surfaces for them: menu rows and a keybinding.
#
# The menu jsonc is generated into the store and is not editable in ~/.config,
# so rows have to be declared. The keybinding rides in its own lua file for the
# same reason bindings.lua does not: bindings.lua is where Omarchy expects
# personal edits and stays user-owned, so it keeps the one hand-written line
#   require("hypr.gog-binds")
# while everything it loads is managed here.
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
