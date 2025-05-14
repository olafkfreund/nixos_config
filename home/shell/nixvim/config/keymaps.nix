{
  config,
  lib,
  pkgs,
  ...
}: {
  programs.nixvim = {
    globals.mapleader = " ";  # Set leader key to space

    keymaps = [
      # Better window navigation
      {
        mode = "n";
        key = "<C-h>";
        action = "<C-w>h";
        options.desc = "Navigate to left window";
      }
      {
        mode = "n";
        key = "<C-j>";
        action = "<C-w>j";
        options.desc = "Navigate to bottom window";
      }
      {
        mode = "n";
        key = "<C-k>";
        action = "<C-w>k";
        options.desc = "Navigate to top window";
      }
      {
        mode = "n";
        key = "<C-l>";
        action = "<C-w>l";
        options.desc = "Navigate to right window";
      }

      # Window resizing
      {
        mode = "n";
        key = "<C-Up>";
        action = ":resize -2<CR>";
        options = {
          silent = true;
          desc = "Resize window up";
        };
      }
      {
        mode = "n";
        key = "<C-Down>";
        action = ":resize +2<CR>";
        options = {
          silent = true;
          desc = "Resize window down";
        };
      }
      {
        mode = "n";
        key = "<C-Left>";
        action = ":vertical resize -2<CR>";
        options = {
          silent = true;
          desc = "Resize window left";
        };
      }
      {
        mode = "n";
        key = "<C-Right>";
        action = ":vertical resize +2<CR>";
        options = {
          silent = true;
          desc = "Resize window right";
        };
      }

      # Buffer navigation
      {
        mode = "n";
        key = "<S-l>";
        action = ":bnext<CR>";
        options = {
          silent = true;
          desc = "Next buffer";
        };
      }
      {
        mode = "n";
        key = "<S-h>";
        action = ":bprevious<CR>";
        options = {
          silent = true;
          desc = "Previous buffer";
        };
      }

      # Better paste
      {
        mode = "v";
        key = "p";
        action = ''"_dP'';
        options = {
          silent = true;
          desc = "Better paste";
        };
      }

      # Stay in indent mode
      {
        mode = "v";
        key = "<";
        action = "<gv";
        options = {
          silent = true;
          desc = "Unindent line";
        };
      }
      {
        mode = "v";
        key = ">";
        action = ">gv";
        options = {
          silent = true;
          desc = "Indent line";
        };
      }

      # Move text up and down
      {
        mode = "v";
        key = "<A-j>";
        action = ":m .+1<CR>==";
        options = {
          silent = true;
          desc = "Move text down";
        };
      }
      {
        mode = "v";
        key = "<A-k>";
        action = ":m .-2<CR>==";
        options = {
          silent = true;
          desc = "Move text up";
        };
      }

      # Quick save
      {
        mode = "n";
        key = "<leader>w";
        action = ":w<CR>";
        options = {
          silent = true;
          desc = "Save file";
        };
      }

      # Quick close
      {
        mode = "n";
        key = "<leader>q";
        action = ":q<CR>";
        options = {
          silent = true;
          desc = "Close window";
        };
      }

      # Clear search highlighting
      {
        mode = "n";
        key = "<leader>h";
        action = ":nohlsearch<CR>";
        options = {
          silent = true;
          desc = "Clear highlights";
        };
      }

      # Center search results
      {
        mode = "n";
        key = "n";
        action = "nzz";
        options = {
          silent = true;
          desc = "Center next search result";
        };
      }
      {
        mode = "n";
        key = "N";
        action = "Nzz";
        options = {
          silent = true;
          desc = "Center previous search result";
        };
      }

      # Better terminal navigation
      {
        mode = "t";
        key = "<C-h>";
        action = "<C-\\><C-N><C-w>h";
        options = {
          silent = true;
          desc = "Navigate to left window from terminal";
        };
      }
      {
        mode = "t";
        key = "<C-j>";
        action = "<C-\\><C-N><C-w>j";
        options = {
          silent = true;
          desc = "Navigate to bottom window from terminal";
        };
      }
      {
        mode = "t";
        key = "<C-k>";
        action = "<C-\\><C-N><C-w>k";
        options = {
          silent = true;
          desc = "Navigate to top window from terminal";
        };
      }
      {
        mode = "t";
        key = "<C-l>";
        action = "<C-\\><C-N><C-w>l";
        options = {
          silent = true;
          desc = "Navigate to right window from terminal";
        };
      }
    ];
  };
}
