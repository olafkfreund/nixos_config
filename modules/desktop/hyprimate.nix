# hyprimate window animations for the Omarchy session (#3237).
{ config, lib, inputs, pkgs, ... }:
with lib; let
  cfg = config.features.hyprimate;
  pkg = inputs.hyprimate.packages.${pkgs.stdenv.hostPlatform.system}.default;
in
{
  options.features.hyprimate.enable = mkEnableOption "hyprimate window animations (Liquid)";
  config = mkIf cfg.enable {
    # Puts the plugin at /run/current-system/sw/lib/hyprimate.so, a path that survives switches.
    environment.systemPackages = [ pkg ];

    home-manager.users.olafkfreund.home.file.".config/hypr/hyprimate.lua" = {
      force = true;
      text = ''
        -- Managed by modules/desktop/hyprimate.nix (#3237).
        -- hl.plugin.load only declares the plugin: Hyprland loads it after this parse, then reloads, so it must be
        -- declared on every parse. The fixed path keeps the running copy across switches; a new build loads at login.
        pcall(hl.config, { decoration = { wobble = { enabled = false } } }) -- upstream: before loading
        hl.plugin.load("/run/current-system/sw/lib/hyprimate.so")

        local ok, style = pcall(hl.get_config, "plugin.hyprimate.window.style")
        if ok and style ~= nil then -- registered: the parse after Hyprland loaded it
          hl.config({ plugin = { hyprimate = { window = {
            style = "liquid",
            options = { liquid = { duration = 500 } },
          } } } })
        end
      '';
    };
  };
}
