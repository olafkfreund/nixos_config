{
  config,
  lib,
  pkgs,
  ...
}: {
  programs.nixvim = {
    # Python-specific setup
    extraPlugins = with pkgs.vimPlugins; [
      vim-python-pep8-indent # Better Python indentation
      pylint-nvim # Python linting integration
      nvim-dap-python # Debug adapter for Python
    ];
    
    filetype = {
      extension = {
        py = "python";
        pyi = "python";
      };
    };
    
    extraConfigLua = ''
      -- Python specific settings
      vim.api.nvim_create_autocmd("FileType", {
        pattern = "python",
        callback = function()
          -- Set PEP8 indentation settings
          vim.opt_local.tabstop = 4
          vim.opt_local.softtabstop = 4
          vim.opt_local.shiftwidth = 4
          vim.opt_local.expandtab = true
          vim.opt_local.textwidth = 88 -- Black's default line length
          
          -- Set Python-specific settings
          vim.opt_local.autoindent = true
          vim.opt_local.fileformat = "unix"
          
          -- Use Python 3 for syntax checking
          if vim.fn.executable("python3") == 1 then
            vim.g.python3_host_prog = vim.fn.exepath("python3")
          end
        end
      })
      
      -- Setup Python debugging
      if pcall(require, "dap-python") then
        local dap_python = require("dap-python")
        dap_python.setup("python3")
        dap_python.test_runner = "pytest"
        
        -- Add virtual environment support
        dap_python.resolve_python = function()
          -- Check for virtual environment
          if vim.env.VIRTUAL_ENV then
            return vim.env.VIRTUAL_ENV .. "/bin/python"
          end
          
          -- Check for Poetry environment
          local poetry_path = vim.fn.getcwd() .. "/poetry.lock"
          if vim.fn.filereadable(poetry_path) == 1 then
            local poetry_python = vim.fn.system("poetry env info -p")
            if vim.v.shell_error == 0 then
              return vim.trim(poetry_python) .. "/bin/python"
            end
          end
          
          -- Check for a local venv directory
          local venv_path = vim.fn.getcwd() .. "/venv"
          if vim.fn.isdirectory(venv_path) == 1 then
            return venv_path .. "/bin/python"
          end
          
          return "python3"
        end
        
        -- Add test keymaps
        vim.keymap.set("n", "<leader>dpt", function()
          require("dap-python").test_method()
        end, { desc = "Debug Python Test Method" })
        
        vim.keymap.set("n", "<leader>dpc", function()
          require("dap-python").test_class()
        end, { desc = "Debug Python Test Class" })
        
        vim.keymap.set("n", "<leader>dps", function()
          require("dap-python").debug_selection()
        end, { desc = "Debug Selected Python Code" })
      end
    '';
    
    # Python-specific LSP configuration
    plugins.lsp.servers = {
      pyright = {
        enable = true;
        settings = {
          python = {
            analysis = {
              autoSearchPaths = true;
              diagnosticMode = "workspace";
              useLibraryCodeForTypes = true;
              typeCheckingMode = "basic";
              inlayHints = {
                variableTypes = true;
                functionReturnTypes = true;
              };
            };
            venvPath = ".";
            pythonPath = "";
          };
        };
      };
    };
    
    # Python formatter configuration
    plugins.conform-nvim.formattersByFt = {
      python = ["isort" "black"];
    };
    
    # Key mappings for Python development
    keymaps = [
      {
        mode = "n";
        key = "<leader>pp";
        action = "<cmd>!python %<CR>";
        options = {
          desc = "Run Python file";
          silent = true;
        };
      }
      {
        mode = "n";
        key = "<leader>pt";
        action = "<cmd>!pytest -xvs %<CR>";
        options = {
          desc = "Run pytest on current file";
          silent = true;
        };
      }
      {
        mode = "n";
        key = "<leader>pf";
        action = "<cmd>!black %<CR>";
        options = {
          desc = "Format with Black";
          silent = true;
        };
      }
      {
        mode = "n";
        key = "<leader>pi";
        action = "<cmd>!isort %<CR>";
        options = {
          desc = "Sort imports with isort";
          silent = true;
        };
      }
      {
        mode = "n";
        key = "<leader>pm";
        action = "<cmd>!mypy %<CR>";
        options = {
          desc = "Type check with mypy";
          silent = true;
        };
      }
    ];
    
    # Configure treesitter for Python
    plugins.treesitter.ensureInstalled = [
      "python"
    ];
  };
}
