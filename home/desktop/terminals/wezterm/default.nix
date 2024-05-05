{ pkgs, config, ... }:{
  
  programs.wezterm = {
    enable = true;
    package = pkgs.wezterm;
    extraConfig = ''
      local wezterm = require 'wezterm'
      local config = wezterm.config_builder()
      config.enable_wayland = true
      config.font = wezterm.font 'JetBrains Mono'
      config.color_scheme = 'Gruvbox Dark (Gogh)'
      config.window_background_opacity = 0.8
      return config
    '';
  };
}
