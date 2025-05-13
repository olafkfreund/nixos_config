{
  config,
  lib,
  pkgs,
  ...
}: {
  programs.nixvim = {
    plugins.telescope = {
      enable = true;
      defaults = {
        prompt_prefix = " ";
        selection_caret = " ";
        mappings = {
          i = {
            # Navigation
            "<C-n>" = "move_selection_next";
            "<C-p>" = "move_selection_previous";

            # History
            "<C-j>" = "cycle_history_next";
            "<C-k>" = "cycle_history_prev";

            # Close telescope
            "<C-c>" = "close";

            # Scrolling preview window
            "<C-u>" = "preview_scrolling_up";
            "<C-d>" = "preview_scrolling_down";
          };
        };
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
        path_display = ["truncate"];
        file_ignore_patterns = [
          "^.git/"
          "^.direnv/"
          "^node_modules/"
          "^__pycache__/"
        ];
      };
      extensions = {
        file_browser.enable = true;
        frecency.enable = true;
        fzf-native.enable = true;
        ui-select.enable = true;
      };

      keymaps = {
        # Find files
        "<leader>ff" = {
          action = "find_files";
          desc = "Find files";
        };
        "<leader>fg" = {
          action = "live_grep";
          desc = "Grep in files";
        };
        "<leader>fw" = {
          action = "grep_string";
          desc = "Find word under cursor";
        };
        "<leader>fb" = {
          action = "buffers";
          desc = "Find buffers";
        };
        "<leader>fh" = {
          action = "help_tags";
          desc = "Find help tags";
        };

        # Git
        "<leader>gc" = {
          action = "git_commits";
          desc = "Git commits";
        };
        "<leader>gs" = {
          action = "git_status";
          desc = "Git status";
        };

        # LSP
        "<leader>lr" = {
          action = "lsp_references";
          desc = "LSP references";
        };
        "<leader>ld" = {
          action = "lsp_definitions";
          desc = "LSP definitions";
        };
      };
    };
  };
}
