{
  config,
  lib,
  pkgs,
  ...
}: {
  programs.nixvim = {
    plugins.which-key = {
      enable = true;
      registrations = {
        "<leader>f" = "Find";
        "<leader>b" = "Buffer";
        "<leader>c" = "Code";
        "<leader>g" = "Git";
        "<leader>l" = "LSP";
        "<leader>s" = "Search";
        "<leader>w" = "Window";
      };
      settings = {
        icons = {
          breadcrumb = "»";
          separator = "➜";
          group = "+";
        };
        window = {
          border = "rounded";
          padding = {
            left = 2;
            right = 2;
            top = 1;
            bottom = 1;
          };
        };
        layout = {
          spacing = 5;
        };
      };
    };
  };
}
