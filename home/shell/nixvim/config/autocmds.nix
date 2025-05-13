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
          __raw = ''
            function()
              vim.highlight.on_yank({ higroup = "IncSearch", timeout = 200 })
            end
          '';
        };
      }

      # Resize splits if window got resized
      {
        event = "VimResized";
        pattern = "*";
        command = "tabdo wincmd =";
      }

      # Go to last location when opening a buffer
      {
        event = "BufReadPost";
        pattern = "*";
        callback = {
          __raw = ''
            function()
              local exclude = { "gitcommit", "gitrebase", "svn", "hgcommit" }
              local buf = vim.api.nvim_get_current_buf()

              if vim.tbl_contains(exclude, vim.bo[buf].filetype) then
                return
              end

              local mark = vim.api.nvim_buf_get_mark(buf, '"')
              local lcount = vim.api.nvim_buf_line_count(buf)
              if mark[1] > 0 and mark[1] <= lcount then
                pcall(vim.api.nvim_win_set_cursor, 0, mark)
              end
            end
          '';
        };
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
        callback = {
          __raw = ''
            function(evt)
              if evt.match:match("^%w%w+://") then
                return
              end
              local file = vim.loop.fs_realpath(evt.match) or evt.match
              vim.fn.mkdir(vim.fn.fnamemodify(file, ":p:h"), "p")
            end
          '';
        };
      }
    ];
  };
}
