{
  config,
  lib,
  pkgs,
  ...
}: {
  programs.nixvim = {
    plugins = {
      telescope = {
        enable = true;
        
        defaults = {
          file_ignore_patterns = [
            "^.git/"
            "^.mypy_cache/"
            "^__pycache__/"
            "^output/"
            "^data/"
            "%.pdf"
            "%.zip"
            "%.tar"
            "%.gz"
          ];
          
          layout_config = {
            horizontal = {
              prompt_position = "top";
              preview_width = 0.55;
            };
            vertical = {
              mirror = false;
            };
            width = 0.87;
            height = 0.80;
            preview_cutoff = 120;
          };

          sorting_strategy = "ascending";
          winblend = 0;
          border = true;
          borderchars = ["─" "│" "─" "│" "╭" "╮" "╯" "╰"];
        };

        keymaps = {
          "<leader>ff" = "find_files";
          "<leader>fg" = "live_grep";
          "<leader>fb" = "buffers";
          "<leader>fh" = "help_tags";
          "<leader>fs" = "lsp_document_symbols";
          "<leader>fr" = "lsp_references";
          "<leader>fd" = "diagnostics";
          "<leader>fo" = "oldfiles";
        };

        extensions = {
          file_browser.enable = true;
          fzf-native.enable = true;
          ui-select.enable = true;
        };
      };
    };

    keymaps = [
      {
        mode = "n";
        key = "<leader>sf";
        action = "<cmd>Telescope find_files<CR>";
        options = {
          desc = "Search files";
          silent = true;
        };
      }
      {
        mode = "n";
        key = "<leader>sg";
        action = "<cmd>Telescope live_grep<CR>";
        options = {
          desc = "Search by grep";
          silent = true;
        };
      }
      {
        mode = "n";
        key = "<leader>sb";
        action = "<cmd>Telescope buffers<CR>";
        options = {
          desc = "Search buffers";
          silent = true;
        };
      }
      {
        mode = "n";
        key = "<leader>sh";
        action = "<cmd>Telescope help_tags<CR>";
        options = {
          desc = "Search help";
          silent = true;
        };
      }
      {
        mode = "n";
        key = "<leader>sd";
        action = "<cmd>Telescope diagnostics<CR>";
        options = {
          desc = "Search diagnostics";
          silent = true;
        };
      }
    ];
  };
}
