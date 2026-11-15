{ config
, lib
, pkgs
, ...
}:
let
  inherit (lib) mkIf;
  cfg = config.features.cli;
in
{
  config = mkIf (cfg.enable && cfg.bat) {
    programs.bat = {
      enable = true;
      config = {
        style = "numbers,changes";
        pager = "less -FR";
      };
      extraPackages = with pkgs.bat-extras; [
        batman
        batpipe
        # batgrep  # Disabled due to failing snapshot tests in bat-extras 2024.08.24
      ];
    };
  };
}
