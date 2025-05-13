{
  config,
  lib,
  pkgs,
  ...
}: {
  programs.nixvim = {
    plugins.neo-tree = {
      enable = true;

      closeIfLastWindow = true;
      defaultComponentConfigs = {
        indent = {
          withExpanders = true;
          expanderCollapsed = "";
          expanderExpanded = "";
          indentSize = 2;
        };
        icon = {
          folderClosed = "";
          folderOpen = "";
          folderEmpty = "";
          default = "";
        };
        name = {
          trailingSlash = true;
          useGitStatusColors = true;
          highlight = "NeoTreeFileName";
        };
        git_status = {
          symbols = {
            added = "✚";
            deleted = "✖";
            modified = "";
            renamed = "";
            untracked = "★";
            ignored = "";
            unstaged = "✗";
            staged = "✓";
            conflict = "";
          };
        };
      };

      window = {
        width = 30;
        mappings = {
          "<space>" = "none";
          "o" = "open";
          "<cr>" = "open";
          "<esc>" = "cancel";
          "P" = {
            command = "toggle_preview";
            config = {use_float = true;};
          };
          "S" = "open_split";
          "s" = "open_vsplit";
          "t" = "open_tabnew";
          "C" = "close_node";
          "z" = "close_all_nodes";
          "R" = "refresh";
          "a" = "add";
          "A" = "add_directory";
          "d" = "delete";
          "r" = "rename";
          "y" = "copy_to_clipboard";
          "x" = "cut_to_clipboard";
          "p" = "paste_from_clipboard";
          "m" = "move";
          "q" = "close_window";
          "?" = "show_help";
        };
      };

      filesystem = {
        followCurrentFile = {
          enabled = true;
          leaveDirsOpen = true;
        };
        useLibuvFileWatcher = true;
        filteredItems = {
          hideDotfiles = false;
          hideGitignored = false;
          alwaysShow = [
            ".gitignored"
            ".env"
          ];
          neverShow = [
            ".DS_Store"
            "thumbs.db"
            "node_modules"
          ];
        };
        windowPosition = "left";
        hijackNetrwBehavior = "open_current";
      };

      buffers = {
        followCurrentFile = {
          enabled = true;
        };
        window = {
          position = "left";
        };
      };

      git_status = {
        window = {
          position = "float";
        };
      };
    };

    keymaps = [
      # Neo-tree focus/toggle
      {
        mode = "n";
        key = "<leader>e";
        action = "<cmd>Neotree toggle<CR>";
        options = {
          desc = "Toggle file explorer";
          silent = true;
        };
      }
      {
        mode = "n";
        key = "<leader>o";
        action = "<cmd>Neotree reveal<CR>";
        options = {
          desc = "Reveal current file";
          silent = true;
        };
      }
      {
        mode = "n";
        key = "<leader>gs";
        action = "<cmd>Neotree float git_status<CR>";
        options = {
          desc = "Git status";
          silent = true;
        };
      }
    ];
  };
}
