{ pkgs, config, ... }:{
  
  programs.wezterm = {
    enable = true;
    package = pkgs.wezterm;
    enableBashIntegration = true;
  };
}
