{
  pkgs,
  lib,
  ...
}: {
  imports = [
    ./colorscheme.nix
    ./which-key.nix
  ];

  programs.nixvim = {
    plugins = {
      # Essential plugins that don't need extensive configuration
      better-escape = {
        enable = true;
        timeout = 200;
      };

      bufferline = {
        enable = true;
        diagnostics = "nvim_lsp";
      };

      comment-nvim.enable = true;
      surround.enable = true;
      illuminate.enable = true;
      lastplace.enable = true;
      nvim-colorizer.enable = true;
    };
  };
}
