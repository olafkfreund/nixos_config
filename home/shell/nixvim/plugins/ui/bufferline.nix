{
  config,
  lib,
  pkgs,
  ...
}: {
  programs.nixvim = {
    plugins.bufferline = {
      enable = true;

      settings = {
        options = {
          mode = "buffers";

          numbers = "none";

          indicator = {
            icon = "▎";
            style = "icon";
          };

          buffer_close_icon = "󰅖";
          modified_icon = "●";
          close_icon = "";
          left_trunc_marker = "";
          right_trunc_marker = "";

          max_name_length = 30;
          max_prefix_length = 30;
          tab_size = 21;

          diagnostics = "nvim_lsp";
          diagnostics_update_in_insert = false;

          diagnostics_indicator = ''
            function(count, level, diagnostics_dict, context)
              local icon = level:match("error") and " " or " "
              return " " .. icon .. count
            end
          '';

          offsets = [
            {
              filetype = "NvimTree";
              text = "File Explorer";
              text_align = "left";
              separator = true;
            }
            {
              filetype = "neo-tree";
              text = "File Explorer";
              text_align = "left";
              separator = true;
            }
          ];

          color_icons = true;
          show_buffer_icons = true;
          show_buffer_close_icons = true;
          show_close_icon = true;
          show_tab_indicators = true;
          show_duplicate_prefix = true;

          persist_buffer_sort = true;
          separator_style = "thin";
          enforce_regular_tabs = true;
          always_show_bufferline = true;

          sort_by = "insert_after_current";
        };
      };
    };

    keymaps = [
      {
        mode = "n";
        key = "<leader>bp";
        action = "<cmd>BufferLineTogglePin<cr>";
        options = {
          desc = "Toggle pin buffer";
          silent = true;
        };
      }
      {
        mode = "n";
        key = "<leader>bo";
        action = "<cmd>BufferLineCloseOthers<cr>";
        options = {
          desc = "Close other buffers";
          silent = true;
        };
      }
      {
        mode = "n";
        key = "<leader>br";
        action = "<cmd>BufferLineCloseRight<cr>";
        options = {
          desc = "Close buffers to the right";
          silent = true;
        };
      }
      {
        mode = "n";
        key = "<leader>bl";
        action = "<cmd>BufferLineCloseLeft<cr>";
        options = {
          desc = "Close buffers to the left";
          silent = true;
        };
      }
    ];
  };
}
