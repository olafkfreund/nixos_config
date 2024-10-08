{
  pkgs,
  config,
  lib,
  imports ? [ ./default_layout.nix ./zjstatus.nix ],
  ...
}: 
with lib; let 
  cfg = config.multiplexer.zellij;
in {
  options.multiplexer.zellij = {
    enable = mkEnableOption {
      default = false;
      description = "Enable zellij";
    };
  };
  config = mkIf cfg.enable {
    # imports = [
    #   ./default_layout.nix
    #   ./zjstatus.nix
    # ];

    programs.zellij = {
      enable = true;
      enableBashIntegration = false;
      enableZshIntegration = false;
      package = pkgs.zellij;
      settings = {
        default-shell = "zsh";
        simplified_ui = true;
        copy_command = lib.getExe' pkgs.wl-clipboard "wl-copy";
        pane_frames = false;
        default_layout = "compact";
        copy_on_select = false;
        hide_session_name = true;
        session_serialization = true;
        ui.pane_frames = {
          hide_session_name = true;
          rounded_corners = true;
        };
        plugins = ["compact-bar" "session-manager" "filepicker" "welcome-screen"];
        theme = lib.mkForce "gruvbox-dark";
      };
    };
    home.shellAliases = {
      zj = "zellij";
    };
    home.packages = with pkgs; [
      zjstatus
      tmate
    ];
  };
}
