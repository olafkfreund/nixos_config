# Omarchy input overrides, shared by p620 and razer.
#
# Omarchy's default/hypr/input.lua takes the layout from /etc/vconsole.conf:
#
#   local kb_layout = vconsole.XKBLAYOUT or "us"
#
# NixOS writes only KEYMAP and FONT into that file, so XKBLAYOUT is never set
# and every Omarchy session came up on a US layout -- while niri, the
# home-manager Hyprland session and services.xserver.xkb were all on gb from
# hosts/common/shared-variables.nix. Rather than bend /etc/vconsole.conf into a
# shape systemd does not ask for, override it in the file Omarchy provides for
# exactly this, ~/.config/hypr/input.lua, which its hyprland.lua requires after
# the defaults.
#
# force: the nixarchy seed copies Omarchy's own input.lua here with `cp -rn`, so
# without it home-manager finds that file in the way and refuses to link.
{ ... }:
{
  home-manager.users.olafkfreund.home.file.".config/hypr/input.lua" = {
    force = true;
    text = ''
      -- Managed by hosts/common/nixos/omarchy-input.nix. Personal input
      -- overrides go here; what is set replaces Omarchy's defaults.
      -- https://wiki.hypr.land/Configuring/Basics/Variables/#input

      hl.config({
        input = {
          kb_layout = "gb",
          kb_variant = "",
        },
      })
    '';
  };
}
