# Super+Alt+U for the Plugin Browser, on homes whose bindings.lua predates it.
#
# nixarchy ships the plugin and its Setup > Plugins > Add Plugin row
# (olafkfreund/nixarchy#915), and seeds Super+Alt+U into bindings.lua -- but
# only for NEW homes: nixarchy never edits an existing bindings.lua. #1991
# dropped this file on the belief that nixarchy binds the key everywhere, which
# left p620 and razer with none (#1995).
#
# Only the key lives here. The menu row is nixarchy's own; overriding it again
# would lose its `when` guard and aliases.
#
# The key rides in its own lua file for the reason omarchy-gog.nix gives:
# bindings.lua stays user-owned and keeps one hand-written
#   pcall(require, "hypr.plugin-browser-binds")
# (already there on p620 and razer), and pcall, not require, so a rollback that
# drops this file cannot take the whole Hyprland config down. `nixarchy-plugin`
# rather than a bare toggle, as nixarchy's own binds: a turned-off plugin is
# named in a notification, not toggled silently.
{ ... }:
{
  home-manager.users.olafkfreund.home.file.".config/hypr/plugin-browser-binds.lua".text = ''
    -- Managed by hosts/common/nixos/omarchy-plugin-browser.nix -- edits here
    -- are overwritten on the next deploy.
    o.bind("SUPER + ALT + U", "Plugin browser", "nixarchy-plugin io.github.olafkfreund.nixarchy-plugin-browser")
  '';
}
