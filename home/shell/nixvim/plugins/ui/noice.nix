{
  config,
  lib,
  pkgs,
  ...
}: {
  programs.nixvim = {
    plugins = {
      noice = {
        enable = true;

        cmdline = {
          enabled = true;
          view = "cmdline_popup";
          opts = {
            border = {
              style = "rounded";
              padding = [0 1];
            };
            position = {
              row = 5;
              col = "50%";
            };
            size = {
              width = "auto";
              height = "auto";
            };
          };
        };

        lsp = {
          override = {
            "vim.lsp.util.convert_input_to_markdown_lines" = true;
            "vim.lsp.util.stylize_markdown" = true;
            "cmp.entry.get_documentation" = true;
          };
          progress = {
            enabled = true;
            format = "lsp_progress";
            formatDone = "lsp_progress_done";
            throttle = 1000 / 30;
            view = "mini";
          };
          hover = {
            enabled = true;
            silent = false;
          };
          signature = {
            enabled = true;
            auto_open = {
              enabled = true;
              trigger = true;
              luasnip = true;
              throttle = 50;
            };
          };
          message = {
            enabled = true;
            view = "notify";
            opts = {};
          };
        };

        presets = {
          bottom_search = true;
          command_palette = true;
          long_message_to_split = true;
          inc_rename = false;
          lsp_doc_border = true;
        };

        routes = [
          {
            filter = {
              event = "msg_show";
              kind = "";
              find = "written";
            };
            opts = {skip = true;};
          }
        ];

        notify = {
          enabled = true;
          view = "notify";
        };

        popupmenu = {
          enabled = true;
          backend = "nui";
        };
      };

      notify = {
        enable = true;
        backgroundColour = "#000000";
        timeout = 3000;
        topDown = true;

        maxWidth = 100;
        maxHeight = 100;

        stages = "fade";

        extraOptions = {
          render = "wrapped-compact";

          icons = {
            DEBUG = "";
            ERROR = "";
            INFO = "";
            TRACE = "✎";
            WARN = "";
          };
        };
      };
    };

    extraPlugins = with pkgs.vimPlugins; [
      nui-nvim # Dependency for noice
    ];

    keymaps = [
      {
        mode = "n";
        key = "<leader>n";
        action = "<cmd>Noice<cr>";
        options = {
          desc = "Noice message history";
          silent = true;
        };
      }
      {
        mode = "n";
        key = "<leader>nl";
        action = "<cmd>NoiceLast<cr>";
        options = {
          desc = "Noice last message";
          silent = true;
        };
      }
      {
        mode = "n";
        key = "<leader>nh";
        action = "<cmd>NoiceHistory<cr>";
        options = {
          desc = "Noice history";
          silent = true;
        };
      }
      {
        mode = "n";
        key = "<leader>na";
        action = "<cmd>NoiceErrors<cr>";
        options = {
          desc = "Noice errors";
          silent = true;
        };
      }
    ];
  };
}
