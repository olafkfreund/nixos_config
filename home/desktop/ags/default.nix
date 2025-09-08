{ config
, lib
, pkgs
, ...
}:
with lib; let
  cfg = config.programs.agspanel;
in
{
  options.programs.agspanel = {
    enable = mkEnableOption {
      default = false;
      description = "Ags panel";
    };
  };
  config = mkIf cfg.enable {
    programs.ags = {
      enable = true;
      extraPackages = with pkgs; [
        gtksourceview
        webkitgtk_4_1 # Use WebKit with libsoup-3 instead of insecure libsoup-2
        accountsservice
      ];
    };
  };
}
