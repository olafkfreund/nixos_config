{
  config,
  lib,
  pkgs,
  ...
}: {
  programs.nixvim = {
    # Shell scripting setup (Bash/Zsh)
    extraPlugins = with pkgs.vimPlugins; [
      vim-sh # Enhanced shell script syntax
    ];
    
    filetype = {
      extension = {
        sh = "sh";
        bash = "bash";
        zsh = "zsh";
        env = "sh";
      };
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
      
      -- Set shellcheck for diagnostics
      vim.api.nvim_create_autocmd("FileType", {
        pattern = {"sh", "bash"},
        callback = function()
          if vim.fn.executable("shellcheck") == 1 then
            vim.opt_local.makeprg = "shellcheck -f gcc %"
            vim.cmd[[compiler gcc]]
          end
        end
      })
      
      -- Special handling for dot files in home directory (likely shell config files)
      vim.api.nvim_create_autocmd({"BufNewFile", "BufRead"}, {
        pattern = {"~/.zshrc", "~/.zshenv", "~/.zprofile", "~/.zlogin", "~/.zlogout"},
        callback = function()
          vim.bo.filetype = "zsh"
        end
      })
      
      vim.api.nvim_create_autocmd({"BufNewFile", "BufRead"}, {
        pattern = {"~/.bashrc", "~/.bash_profile", "~/.profile", "~/.bash_login", "~/.bash_logout"},
        callback = function()
          vim.bo.filetype = "bash"
        end
      })
      
      vim.api.nvim_create_autocmd({"BufNewFile", "BufRead"}, {
        pattern = {"*.env", "*.env.*", ".env*"},
        callback = function()
          vim.bo.filetype = "sh"
        end
      })
      
      -- Configure shell script syntax highlighting
      vim.g.is_bash = 1  -- Default to bash syntax for sh files
      vim.g.sh_fold_enabled = 3  -- Enable folding for shell scripts (functions and heredocs)
      vim.g.sh_no_error = 1  -- Don't highlight errors (let shellcheck handle this)
    '';
    
    # Key mappings for shell scripts
    keymaps = [
      {
        mode = "n";
        key = "<leader>sr";
        action = ":!chmod +x % && ./%<CR>";
        options = {
          desc = "Make executable and run script";
          silent = true;
        };
      }
      {
        mode = "n";
        key = "<leader>sc";
        action = ":!shellcheck %<CR>";
        options = {
          desc = "Run shellcheck";
          silent = true;
        };
      }
      {
        mode = "n";
        key = "<leader>sf";
        action = ":!shfmt -i 2 -ci -w %<CR>";
        options = {
          desc = "Format shell script with shfmt";
          silent = true;
        };
      }
    ];
    
    # Configure treesitter for shell scripts
    plugins.treesitter.ensureInstalled = [
      "bash"
    ];
    
    # Configure LSP for shell scripts
    plugins.lsp.servers = {
      bashls = {
        enable = true;
        filetypes = ["sh" "bash" "zsh"];
        settings = {
          bashIde = {
            globPattern = "**/*@(.sh|.inc|.bash|.zsh|.command|.env|.env.*)";
            shellcheckPath = "${pkgs.shellcheck}/bin/shellcheck";
            shellcheckArguments = "-x";
            explainshellEndpoint = "";
          };
        };
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
