{ pkgs
, config
, lib
, ...
}:
let
  inherit (lib) mkIf;
  cfg = config.features.cli;
in
{
  config = mkIf (cfg.enable && cfg.gh) {
    programs.gh = {
      enable = true;
      extensions = with pkgs; [
        gh-dash
        gh-markdown-preview
        gh-notify
        # gh-copilot removed - deprecated and archived upstream
      ];
    };
  };
}
