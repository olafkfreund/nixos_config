{
  pkgs,
  lib,
  ...
}: {
  programs.nixvim = {
    plugins = {
      treesitter = {
        grammarPackages = with pkgs.vimPlugins.nvim-treesitter.builtGrammars; [
          python
        ];
      };

      lsp = {
        servers = {
          pyright = {
            enable = true;
            settings = {
              python = {
                analysis = {
                  autoSearchPaths = true;
                  useLibraryCodeForTypes = true;
                  diagnosticMode = "workspace";
                  typeCheckingMode = "basic";
                };
              };
            };
          };
        };
      };

      none-ls = {
        enable = true;
        sources = {
          formatting = {
            black.enable = true;
            isort.enable = true;
          };
          diagnostics = {
            flake8.enable = true;
            mypy.enable = true;
          };
        };
      };
    };

    extraPlugins = with pkgs.vimPlugins; [
      vim-python-pep8-indent # Better Python indentation
      pylint-nvim # Python linting integration
      nvim-dap-python # Debug adapter for Python
    ];

    filetype.extension = {
      py = "python";
      pyi = "python";
    };

    extraConfigLua = ''
      -- Python-specific settings
      vim.api.nvim_create_autocmd("FileType", {
        pattern = "python",
        callback = function()
          -- Set Python indentation
          vim.opt_local.expandtab = true
          vim.opt_local.shiftwidth = 4
          vim.opt_local.tabstop = 4
          vim.opt_local.softtabstop = 4
          vim.opt_local.autoindent = true
          vim.opt_local.smartindent = true
          vim.opt_local.textwidth = 88 -- Black's default line length
          vim.opt_local.fileformat = "unix"

          -- Add Python path to path for better import resolution
          local handle = io.popen("which python3")
          if handle then
            local python_path = handle:read("*a")
            handle:close()
            if python_path then
              vim.opt_local.path:append(python_path:gsub("\n", "") .. "/lib/python*/site-packages")
            end
          end

          -- Use Python 3 for syntax checking
          if vim.fn.executable("python3") == 1 then
            vim.g.python3_host_prog = vim.fn.exepath("python3")
          end
        end
      })

      -- Configure Python debugging
      local dap = require('dap')
      dap.adapters.python = {
        type = 'executable';
        command = 'python3';
        args = { '-m', 'debugpy.adapter' };
      }

      dap.configurations.python = {
        {
          type = 'python';
          request = 'launch';
          name = "Launch file";
          program = "''${file}";
          pythonPath = function()
            return 'python3'
          end;
        },
      }
    '';

    # Python-specific keymaps
    keymaps = [
      {
        mode = "n";
        key = "<leader>pt";
        action = ":!python3 %<CR>";
        options = {
          silent = true;
          desc = "Run Python file";
        };
      }
      {
        mode = "n";
        key = "<leader>pi";
        action = ":!pip install -r requirements.txt<CR>";
        options = {
          silent = true;
          desc = "Install Python dependencies";
        };
      }
    ];
  };
}
