{pkgs, ...}: {
  programs.nixvim = {
    # Shell scripting setup (Bash/Zsh)
    extraPlugins = with pkgs.vimPlugins; [
      vim-sh # Enhanced shell script syntax
    ];

    filetype.extension = {
      sh = "sh";
      bash = "bash";
      zsh = "zsh";
      env = "sh";
    };

    extraConfigLua = ''
      -- Shell script specific settings
      vim.api.nvim_create_autocmd("FileType", {
        pattern = {"sh", "bash", "zsh"},
        callback = function()
          -- Set indentation for shell scripts
          vim.opt_local.tabstop = 2
          vim.opt_local.softtabstop = 2
          vim.opt_local.shiftwidth = 2
          vim.opt_local.expandtab = true

          -- Detect shebang and set filetype accordingly
          local first_line = vim.api.nvim_buf_get_lines(0, 0, 1, false)[1] or ""
          if first_line:match("#!/bin/bash") or first_line:match("#!/usr/bin/env bash") then
            vim.bo.filetype = "bash"
          elseif first_line:match("#!/bin/zsh") or first_line:match("#!/usr/bin/env zsh") then
            vim.bo.filetype = "zsh"
          end
        end
      })

      -- Configure shell script syntax highlighting
      vim.g.is_bash = 1  -- Default to bash syntax for sh files
      vim.g.sh_fold_enabled = 3  -- Enable folding for shell scripts (functions and heredocs)
      vim.g.sh_no_error = 1  -- Don't highlight errors (let shellcheck handle this)
    '';

    # Configure LSP for shell scripts
    plugins.lsp.servers.bashls = {
      enable = true;
      filetypes = ["sh" "bash" "zsh"];
      settings = {
        includeAllWorkspaceSymbols = true;
        useGitHubCopilotIgnore = true;
      };
    };

    # Configure conform.nvim for shell formatting
    plugins.conform-nvim.formattersByFt = {
      sh = ["shfmt"];
      bash = ["shfmt"];
      zsh = ["shfmt"];
    };
  };
}
