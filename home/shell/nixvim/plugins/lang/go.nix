{
  config,
  lib,
  pkgs,
  ...
}: {
  programs.nixvim = {
    # Go-specific setup
    extraPlugins = with pkgs.vimPlugins; [
      vim-go # Enhanced Go support
      nvim-dap-go # Debug adapter for Go
    ];

    extraConfigLua = ''
      -- Go specific settings
      vim.api.nvim_create_autocmd("FileType", {
        pattern = "go",
        callback = function()
          -- Use tabs in Go files as per Go standards
          vim.opt_local.tabstop = 4
          vim.opt_local.shiftwidth = 4
          vim.opt_local.expandtab = false

          -- Auto import on save
          vim.opt_local.autowrite = true
        end
      })

      -- Configure vim-go
      vim.g.go_highlight_types = 1
      vim.g.go_highlight_fields = 1
      vim.g.go_highlight_functions = 1
      vim.g.go_highlight_function_calls = 1
      vim.g.go_highlight_operators = 1
      vim.g.go_highlight_extra_types = 1
      vim.g.go_highlight_build_constraints = 1

      -- Don't run go imports on autosave as LSP will handle this
      vim.g.go_imports_autosave = 0

      -- Don't run go fmt on autosave as LSP will handle this
      vim.g.go_fmt_autosave = 0

      -- Use gopls for go to definition
      vim.g.go_def_mode = 'gopls'
      vim.g.go_info_mode = 'gopls'

      -- Setup Go debugging
      if pcall(require, "dap-go") then
        require("dap-go").setup()

        -- Add test keymaps
        vim.keymap.set("n", "<leader>dgt", function()
          require("dap-go").debug_test()
        end, { desc = "Debug Go Test" })

        vim.keymap.set("n", "<leader>dgl", function()
          require("dap-go").debug_last()
        end, { desc = "Debug Last Go Test" })
      end
    '';

    # Key mappings for Go development
    keymaps = [
      {
        mode = "n";
        key = "<leader>gr";
        action = "<cmd>GoRun<CR>";
        options = {
          desc = "Go Run";
          silent = true;
        };
      }
      {
        mode = "n";
        key = "<leader>gt";
        action = "<cmd>GoTest<CR>";
        options = {
          desc = "Go Test";
          silent = true;
        };
      }
      {
        mode = "n";
        key = "<leader>gi";
        action = "<cmd>GoImports<CR>";
        options = {
          desc = "Go Imports";
          silent = true;
        };
      }
      {
        mode = "n";
        key = "<leader>gb";
        action = "<cmd>GoBuild<CR>";
        options = {
          desc = "Go Build";
          silent = true;
        };
      }
      {
        mode = "n";
        key = "<leader>gc";
        action = "<cmd>GoCoverage<CR>";
        options = {
          desc = "Go Coverage";
          silent = true;
        };
      }
    ];
  };
}
