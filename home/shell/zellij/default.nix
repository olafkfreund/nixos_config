{ pkgs, lib,...}: {
  
  programs.zellij = {
    enable = true;
    enableBashIntegration = false;
    enableZshIntegration = false;
    package = pkgs.zellij;
    settings = {
      default-shell = "zsh";
      simplified_ui = true;
        pane_frames = false;
        default_layout = "compact";
        copy_on_select = false;
        hide_session_name = true;
        session_serialization = false;
        ui.pane_frames = {
          hide_session_name = true;
        };
        plugins = ["compact-bar" "session-manager" "filepicker" "welcome-screen"];
        theme = lib.mkForce "gruvbox-dark";
    };
  };
}

