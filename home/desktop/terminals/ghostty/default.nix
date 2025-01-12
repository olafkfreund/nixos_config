{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.ghostty;
in {
  options.ghostty = {
    enable = mkEnableOption {
      default = false;
      description = "ghostty";
    };
  };
  # config = mkIf cfg.enable {
  #   xdg.mimeApps = {
  #     associations.added = {
  #       "x-scheme-handler/terminal" = "ghostty.desktop";
  #     };
  #     defaultApplications = {
  #       "x-scheme-handler/terminal" = "ghostty.desktop";
  #     };
  #   };

    programs.ghostty = {
      enable = true;
      package = pkgs.ghostty;
      shellIntegration = {
        enableZshIntegration = true;
        enableBashIntegration = true;
      };
    };
  };
}
