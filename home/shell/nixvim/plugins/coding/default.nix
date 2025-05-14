{
  config,
  lib,
  pkgs,
  ...
}: {
  imports = [
    ./lsp.nix
    ./completion.nix
    ./copilot.nix
  ];

  programs.nixvim = {
    plugins = {
      # Development helpers that don't need extensive configuration
      nix.enable = true;

      fidget.enable = true;

      lsp-format.enable = true;

      rust-tools.enable = true;

      ts-autotag.enable = true;

      todo-comments = {
        enable = true;
        signs = true;
        keywords = {
          FIX = {
            icon = " ";
            color = "error";
            alt = ["FIXME" "BUG" "FIXIT" "ISSUE"];
          };
          TODO = {
            icon = " ";
            color = "info";
          };
          HACK = {
            icon = " ";
            color = "warning";
          };
          WARN = {
            icon = " ";
            color = "warning";
            alt = ["WARNING" "XXX"];
          };
          NOTE = {
            icon = " ";
            color = "hint";
            alt = ["INFO"];
          };
        };
      };
    };
  };
}
