{
  config,
  lib,
  pkgs,
  ...
}: {
  programs.nixvim = {
    # Markdown-specific setup
    plugins = {
      markdown-preview = {
        enable = true;
        autoStart = false;
        mkit = {
          breaks = false;
          html = true;
          linkify = true;
          typographer = true;
        };
        theme = "dark";
        extraSettings = {
          sync_scroll_type = "middle";
          disable_filename = false;
        };
      };
    };

    extraPlugins = with pkgs.vimPlugins; [
      vim-table-mode # For easier table editing
      vim-markdown # Enhanced markdown syntax
      vim-markdown-toc # Table of Contents generation
    ];

    extraConfigLua = ''
      -- Markdown specific settings
      vim.api.nvim_create_autocmd("FileType", {
        pattern = "markdown",
        callback = function()
          -- Set wrap and spell for markdown files
          vim.opt_local.wrap = true
          vim.opt_local.spell = true
          vim.opt_local.spelllang = "en_us"
          vim.opt_local.conceallevel = 2

          -- Set textwidth for automatic line breaks
          vim.opt_local.textwidth = 80

          -- Automatically insert list items
          vim.opt_local.formatoptions = vim.opt_local.formatoptions + "r"

          -- Enable Table Mode for Markdown
          vim.g.table_mode_corner = '|'
          vim.g.table_mode_header_fillchar = '-'
        end
      })

      -- Configure markdown settings
      vim.g.vim_markdown_folding_disabled = 1
      vim.g.vim_markdown_frontmatter = 1
      vim.g.vim_markdown_strikethrough = 1
      vim.g.vim_markdown_new_list_item_indent = 2
      vim.g.vim_markdown_auto_insert_bullets = 1
      vim.g.vim_markdown_toc_autofit = 1

      -- Markdown preview settings
      vim.g.mkdp_auto_close = 0
      vim.g.mkdp_refresh_slow = 0
      vim.g.mkdp_browser = ""  -- Use default browser
    '';

    keymaps = [
      {
        mode = "n";
        key = "<leader>mp";
        action = "<cmd>MarkdownPreview<CR>";
        options = {
          desc = "Markdown Preview";
          silent = true;
        };
      }
      {
        mode = "n";
        key = "<leader>mt";
        action = "<cmd>TableModeToggle<CR>";
        options = {
          desc = "Toggle Table Mode";
          silent = true;
        };
      }
      {
        mode = "n";
        key = "<leader>mc";
        action = "<cmd>GenTocGFM<CR>";
        options = {
          desc = "Generate TOC";
          silent = true;
        };
      }
    ];
  };
}
