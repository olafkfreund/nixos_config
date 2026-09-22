# The Plugin Browser (olafkfreund/nixarchy-plugin-browser) as this desktop's
# way to add a plugin: a menu row and a keybinding. The plugin itself is
# installed with its own install.sh and enabled with `omarchy plugin enable`;
# this file only points the desktop at it.
#
# Setup > Plugins > Add Plugin is overridden by id. An override that omits a
# key blanks it instead of inheriting it (MenuModel.js normalizes the row
# first), so icon, label and action are all restated.
#
# The keybinding rides in its own lua file for the reason omarchy-gog.nix
# gives: bindings.lua stays user-owned and keeps one hand-written
#   pcall(require, "hypr.plugin-browser-binds")
# and pcall, not require, so a rollback that drops this file cannot take the
# whole Hyprland config down.
{ ... }:
{
  programs.nixarchy.menu.extraEntries."setup.plugin.add" = {
    icon = "󰖟";
    label = "Add Plugin";
    action = "omarchy-shell shell toggle io.github.olafkfreund.nixarchy-plugin-browser '{}'";
  };

  home-manager.users.olafkfreund.home.file.".config/hypr/plugin-browser-binds.lua".text = ''
    -- Managed by hosts/common/nixos/omarchy-plugin-browser.nix -- edits here
    -- are overwritten on the next deploy.
    o.bind("SUPER + ALT + U", "Plugin browser", "omarchy-shell shell toggle io.github.olafkfreund.nixarchy-plugin-browser '{}'")
  '';
}
