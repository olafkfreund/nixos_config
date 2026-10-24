# Nixi's snowflake desktop companion (nixarchy#1432), shared by p620 and razer.
# nixarchy supplies the package; this turns it on and gives it keys. The binds
# ride in their own lua file, loaded from the user-owned bindings.lua with
#   pcall(require, "hypr.nixi-companion-binds")
# pcall for the reason omarchy-gog.nix gives: bindings.lua outlives a
# generation that stops providing the file. SUPER+ALT+H is Herdr, hence S.
{ ... }:
{
  home-manager.users.olafkfreund = {
    services.nixi.companion.enable = true;

    home.file.".config/hypr/nixi-companion-binds.lua".text = ''
      -- Managed by hosts/common/nixos/omarchy-nixi-companion.nix -- edits here
      -- are overwritten on the next deploy.
      o.bind("SUPER + ALT + S", "Nixi companion: show or hide", "nixi-companion")
      o.bind("SUPER + ALT + SHIFT + S", "Nixi companion: listen", "nixi-companion listen")
    '';
  };
}
