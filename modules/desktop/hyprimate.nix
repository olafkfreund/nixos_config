# hyprimate window animations for the Omarchy session (#3237).
{ config, lib, inputs, pkgs, ... }:
with lib; let
  cfg = config.features.hyprimate;
  pkg = inputs.hyprimate.packages.${pkgs.stdenv.hostPlatform.system}.default;
in
{
  options.features.hyprimate.enable = mkEnableOption "hyprimate window animations (Liquid)";
  config = mkIf cfg.enable {
    home-manager.users.olafkfreund.home.file.".config/hypr/hyprimate.lua" = {
      force = true;
      text = ''
        -- Managed by modules/desktop/hyprimate.nix (#3237).
        local function registered()
          local ok, v = pcall(hl.get_config, "plugin.hyprimate.window.style")
          return ok and v ~= nil
        end
        local function warn(msg)
          hl.exec_cmd("omarchy-notification-send " .. o.shell_quote("hyprimate: " .. msg))
        end

        pcall(hl.config, { decoration = { wobble = { enabled = false } } }) -- upstream: before loading
        if not registered() then
          local ok, err = pcall(hl.plugin.load, "${pkg}/lib/hyprimate.so")
          if not ok then warn("load failed: " .. tostring(err)) end
        end
        if registered() then
          hl.config({ plugin = { hyprimate = { window = {
            style = "liquid",
            options = { liquid = { duration = 200 } },
          } } } })
        else
          warn("not loaded; stock animations")
        end
      '';
    };
  };
}
