{
  config,
  lib,
  pkgs,
  ...
}: {
  programs.nixvim = {
    keymaps = [
      # Better window navigation
      {
        mode = "n";
        key = "<C-h>";
        action = "<C-w>h";
        options = {
          desc = "Navigate to left window";
          silent = true;
        };
      }
      {
        mode = "n";
        key = "<C-j>";
        action = "<C-w>j";
        options = {
          desc = "Navigate to bottom window";
          silent = true;
        };
      }
      {
        mode = "n";
        key = "<C-k>";
        action = "<C-w>k";
        options = {
          desc = "Navigate to top window";
          silent = true;
        };
      }
      {
        mode = "n";
        key = "<C-l>";
        action = "<C-w>l";
        options = {
          desc = "Navigate to right window";
          silent = true;
        };
      }

      # Buffer navigation
      {
        mode = "n";
        key = "<S-h>";
        action = ":bprevious<CR>";
        options = {
          desc = "Previous buffer";
          silent = true;
        };
      }
      {
        mode = "n";
        key = "<S-l>";
        action = ":bnext<CR>";
        options = {
          desc = "Next buffer";
          silent = true;
        };
      }

      # Better indenting
      {
        mode = "v";
        key = "<";
        action = "<gv";
        options = {
          desc = "Outdent line";
          silent = true;
        };
      }
      {
        mode = "v";
        key = ">";
        action = ">gv";
        options = {
          desc = "Indent line";
          silent = true;
        };
      }

      # Move lines
      {
        mode = "v";
        key = "J";
        action = ":m '>+1<CR>gv=gv";
        options = {
          desc = "Move lines down";
          silent = true;
        };
      }
      {
        mode = "v";
        key = "K";
        action = ":m '<-2<CR>gv=gv";
        options = {
          desc = "Move lines up";
          silent = true;
        };
      }

      # Clear search with <Esc>
      {
        mode = "n";
        key = "<Esc>";
        action = "<cmd>nohlsearch<CR>";
        options = {
          desc = "Clear search highlights";
          silent = true;
        };
      }

      # Diagnostic keymaps
      {
        mode = "n";
        key = "[d";
        action = "vim.diagnostic.goto_prev";
        options = {
          desc = "Go to previous diagnostic";
          silent = true;
          lua = true;
        };
      }
      {
        mode = "n";
        key = "]d";
        action = "vim.diagnostic.goto_next";
        options = {
          desc = "Go to next diagnostic";
          silent = true;
          lua = true;
        };
      }
      {
        mode = "n";
        key = "<leader>e";
        action = "vim.diagnostic.open_float";
        options = {
          desc = "Show diagnostic error messages";
          silent = true;
          lua = true;
        };
      }
      {
        mode = "n";
        key = "<leader>q";
        action = "vim.diagnostic.setloclist";
        options = {
          desc = "Open diagnostic quickfix list";
          silent = true;
          lua = true;
        };
      }
    ];
  };
}
