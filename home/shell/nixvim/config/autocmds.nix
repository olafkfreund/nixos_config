{
  config,
  lib,
  pkgs,
  ...
}: {
  programs.nixvim = {
    autoCmd = [
      # Highlight on yank
      {
        event = "TextYankPost";
        pattern = "*";
        callback = {
          __raw = ''function() vim.highlight.on_yank { timeout=200 } end'';
        };
      }

      # Resize splits if window got resized
      {
        event = "VimResized";
        pattern = "*";
        command = "wincmd =";
      }

      # Go to last location when opening a buffer
      {
        event = "BufReadPost";
        pattern = "*";
        command = ''if line("'\"") > 0 && line("'\"") <= line("$") | exe "normal! g`\"" | endif'';
      }

      # Auto toggle relative line numbers when in insert mode
      {
        event = ["InsertEnter"];
        pattern = "*";
        callback = {
          __raw = ''
            function()
              vim.opt.relativenumber = false
            end
          '';
        };
      }
      {
        event = ["InsertLeave"];
        pattern = "*";
        callback = {
          __raw = ''
            function()
              vim.opt.relativenumber = true
            end
          '';
        };
      }

      # Auto create dir when saving a file where some intermediate directory doesn't exist
      {
        event = "BufWritePre";
        pattern = "*";
        command = ''if '<afile>' !~ '^scp:' && !isdirectory(expand('<afile>:h')) | call mkdir(expand('<afile>:h'), 'p') | endif'';
      }

      # Auto format on save (if formatter available)
      {
        event = "BufWritePre";
        pattern = "*";
        command = "try | undojoin | Neoformat | catch /^Vim/ | endtry";
      }

      # Set indent size for specific filetypes
      {
        event = "FileType";
        pattern = ["nix" "yaml" "json"];
        command = "setlocal shiftwidth=2 tabstop=2";
      }

      # Start git commits in insert mode
      {
        event = "FileType";
        pattern = "gitcommit,gitrebase";
        command = "startinsert | 1";
      }

      # Remove trailing whitespace on save
      {
        event = "BufWritePre";
        pattern = "*";
        command = "%s/\\s\\+$//e";
      }

      # Auto reload file when changed externally
      {
        event = ["FocusGained" "BufEnter"];
        pattern = "*";
        command = "if mode() != 'c' | checktime | endif";
      }

      # Terminal settings
      {
        event = "TermOpen";
        pattern = "*";
        command = "setlocal nonumber norelativenumber signcolumn=no";
      }

      # Automatically enter insert mode in terminal
      {
        event = "BufEnter";
        pattern = "term://*";
        command = "startinsert";
      }
    ];

    # File type detection
    autoGroups = {
      clarity_ft = {
        clear = true;
      };
      yaml_ft = {
        clear = true;
      };
    };
  };
}
