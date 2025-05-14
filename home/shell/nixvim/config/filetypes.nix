{
  config,
  lib,
  pkgs,
  ...
}: {
  programs.nixvim = {
    autoCmd = [
      # Set indent for specific file types
      {
        event = "FileType";
        pattern = ["lua"];
        command = "setlocal shiftwidth=2 tabstop=2";
      }
      {
        event = "FileType";
        pattern = ["nix"];
        command = "setlocal shiftwidth=2 tabstop=2";
      }
      {
        event = "FileType";
        pattern = ["python"];
        command = "setlocal shiftwidth=4 tabstop=4";
      }
      {
        event = "FileType";
        pattern = ["markdown"];
        command = "setlocal wrap linebreak";
      }

      # Treesitter based folding
      {
        event = "FileType";
        pattern = ["lua" "nix" "rust" "go" "typescript" "javascript" "json" "python"];
        command = "setlocal foldmethod=expr foldexpr=nvim_treesitter#foldexpr() foldlevel=99";
      }
    ];

    # File type specific settings using ftplugin
    ftplugin = {
      markdown = {
        # Enable spell checking for markdown files
        opts = {
          spell = true;
        };
      };

      gitcommit = {
        # Set textwidth for git commit messages
        opts = {
          textwidth = 72;
          spell = true;
        };
      };

      lua = {
        # Format on save for lua files
        opts = {
          formatoptions = "jcroqlnt";
        };
      };

      nix = {
        # Format on save for nix files
        opts = {
          formatoptions = "jcroqlnt";
        };
      };
    };

    filetype.enable = true;

    globals = {
      # Markdown settings
      vim_markdown_folding_disabled = 1;
      vim_markdown_frontmatter = 1;
      vim_markdown_conceal = 0;
      vim_markdown_fenced_languages = [
        "nix"
        "python"
        "bash=sh"
        "javascript"
        "typescript"
        "yaml"
        "json"
      ];

      # Shell script settings
      is_bash = 1;
      no_bash_arrays = 1;

      # Python settings
      python_highlight_all = 1;
    };

    # Filetype-specific settings
    extraConfigLua = ''
      -- Function to set up buffer-local keymaps
      local function buf_set_keymaps(bufnr, keymaps)
        for mode, maps in pairs(keymaps) do
          for key, cmd in pairs(maps) do
            vim.api.nvim_buf_set_keymap(bufnr, mode, key, cmd, { noremap = true, silent = true })
          end
        end
      end

      -- Nix files
      vim.api.nvim_create_autocmd("FileType", {
        pattern = "nix",
        callback = function()
          vim.opt_local.commentstring = "# %s"
          vim.opt_local.tabstop = 2
          vim.opt_local.shiftwidth = 2
          vim.opt_local.expandtab = true
        end
      })

      -- Markdown files
      vim.api.nvim_create_autocmd("FileType", {
        pattern = "markdown",
        callback = function()
          vim.opt_local.spell = true
          vim.opt_local.wrap = true
          vim.opt_local.conceallevel = 0
        end
      })

      -- YAML files
      vim.api.nvim_create_autocmd("FileType", {
        pattern = {"yaml", "yaml.docker-compose"},
        callback = function()
          vim.opt_local.tabstop = 2
          vim.opt_local.shiftwidth = 2
          vim.opt_local.expandtab = true
        end
      })

      -- Shell scripts
      vim.api.nvim_create_autocmd("FileType", {
        pattern = {"sh", "bash", "zsh"},
        callback = function()
          vim.opt_local.tabstop = 2
          vim.opt_local.shiftwidth = 2
          vim.opt_local.expandtab = true
        end
      })

      -- Git commit messages
      vim.api.nvim_create_autocmd("FileType", {
        pattern = "gitcommit",
        callback = function()
          vim.opt_local.spell = true
          vim.opt_local.textwidth = 72
          vim.opt_local.colorcolumn = "72"
        end
      })

      -- Help files
      vim.api.nvim_create_autocmd("FileType", {
        pattern = "help",
        callback = function()
          -- Press q to close help window
          vim.api.nvim_buf_set_keymap(0, "n", "q", ":q<CR>", { noremap = true, silent = true })
        end
      })
    '';
  };
}
