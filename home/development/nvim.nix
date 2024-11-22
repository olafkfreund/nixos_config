{
  lib,
  config,
  inputs,
  pkgs,
  ...
}:
with lib; let
  cfg = config.editor.neovim;
in {
  options.editor.neovim = {
    enable = mkEnableOption {
      default = false;
      description = "neovim";
    };
  };
  config = mkIf cfg.enable {
    programs.neovim = {
      enable = true;
      defaultEditor = true;
      viAlias = true;
      vimAlias = true;
      vimdiffAlias = true;
      withPython3 = true;
      withRuby = true;
      withNodeJs = true;
      extraPackages = with pkgs; [
        codeium
        # neovide
        nixd
      ];
    };
  };
}
