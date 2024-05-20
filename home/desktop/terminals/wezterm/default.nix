{ pkgs, config, ... }:{
  
  programs.wezterm = {
    enable = true;
    package = pkgs.wezterm;
<<<<<<< HEAD
    enableBashIntegration = true;
=======
    extraConfig = ''
      local wezterm = require 'wezterm'
      local config = wezterm.config_builder()
      config.font = wezterm.font 'JetBrains Mono'
      config.color_scheme = 'Gruvbox Dark (Gogh)'
      config.window_background_opacity = 0.8
      return config
    '';
>>>>>>> 6f826e2188d86f7d0c76929d56e6cedb6863fd9d
  };
}
