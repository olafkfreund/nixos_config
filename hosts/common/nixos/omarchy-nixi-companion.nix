# Nixi's snowflake desktop companion (nixarchy#1432), shared by p620 and razer.
# nixarchy supplies the package; this turns it on and gives it keys. The binds
# ride in their own lua file, loaded from the user-owned bindings.lua with
#   pcall(require, "hypr.nixi-companion-binds")
# pcall for the reason omarchy-gog.nix gives: bindings.lua outlives a
# generation that stops providing the file. SUPER+ALT+S is Omarchy's scratchpad (#2714).
{ ... }:
{
  imports = [ ../../../modules/programs/nixi-agent-hooks.nix ];
  features.nixiAgentHooks.enable = true;

  home-manager.users.olafkfreund = {
    services.nixi.companion.enable = true;
    # A "done" note when a shell command of 30 s or more ends in a terminal you are not looking at (nixi#133).
    services.nixi.companion.commandDone.enable = true;

    home.file.".config/hypr/nixi-companion-binds.lua".text = ''
      -- Managed by hosts/common/nixos/omarchy-nixi-companion.nix -- edits here
      -- are overwritten on the next deploy.
      o.bind("SUPER + ALT + H", "Nixi companion: show or hide", "nixi-companion")
      o.bind("SUPER + ALT + SHIFT + S", "Nixi companion: listen", "nixi-companion listen")
      -- size: SUPER+ALT+-/= are Omarchy's window nudges, so CTRL joins (keycodes, as Omarchy binds them: any layout)
      o.bind("SUPER + CTRL + ALT + code:21", "Nixi companion: bigger", "nixi-companion size up")
      o.bind("SUPER + CTRL + ALT + code:20", "Nixi companion: smaller", "nixi-companion size down")
      o.bind("SUPER + CTRL + ALT + code:19", "Nixi companion: normal size", "nixi-companion size reset")
      -- Start him with the session: activation only restarts a running one, so a fresh host never got him.
      o.exec_on_start("nixi-companion show")
    '';
  };
}
