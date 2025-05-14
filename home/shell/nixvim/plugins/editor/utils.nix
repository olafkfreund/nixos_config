{
  pkgs,
  lib,
  ...
}: {
  programs.nixvim = {
    plugins = {
      # Better commenting
      comment-nvim.enable = true;

      # Add/change/delete surroundings
      surround.enable = true;

      # Better f/F/t/T motions
      leap.enable = true;

      # Start screen
      alpha = {
        enable = true;
        layout = [
          {
            type = "padding";
            val = 2;
          }
          {
            type = "text";
            val = [
              "███╗   ██╗██╗██╗  ██╗██╗   ██╗██╗███╗   ███╗"
              "████╗  ██║██║╚██╗██╔╝██║   ██║██║████╗ ████║"
              "██╔██╗ ██║██║ ╚███╔╝ ██║   ██║██║██╔████╔██║"
              "██║╚██╗██║██║ ██╔██╗ ╚██╗ ██╔╝██║██║╚██╔╝██║"
              "██║ ╚████║██║██╔╝ ██╗ ╚████╔╝ ██║██║ ╚═╝ ██║"
              "╚═╝  ╚═══╝╚═╝╚═╝  ╚═╝  ╚═══╝  ╚═╝╚═╝     ╚═╝"
            ];
            opts = {
              position = "center";
              hl = "Type";
            };
          }
          {
            type = "padding";
            val = 2;
          }
          {
            type = "group";
            val = [
              {
                command = "<CMD>ene <CR>";
                desc = "  New file";
                shortcut = "e";
              }
              {
                command = ":qa<CR>";
                desc = "  Quit Neovim";
                shortcut = "q";
              }
            ];
          }
        ];
      };

      # Indentation guides
      indent-blankline = {
        enable = true;
        indent = {
          char = "│";
        };
        scope = {
          enabled = true;
          showStart = true;
          showEnd = true;
        };
      };

      # Shows pending keybinds
      which-key.enable = true;

      # Code folding
      fold-preview.enable = true;

      # Smooth scrolling
      neoscroll.enable = true;

      # Multiple cursors
      multiple-cursors.enable = true;

      # Better matchparen
      matchparen-nvim.enable = true;
    };
  };
}
