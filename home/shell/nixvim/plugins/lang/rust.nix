{
  pkgs,
  lib,
  ...
}: {
  programs.nixvim = {
    plugins = {
      treesitter = {
        grammarPackages = with pkgs.vimPlugins.nvim-treesitter.builtGrammars; [
          rust
          toml
        ];
      };

      rust-tools = {
        enable = true;
        server = {
          check = {
            command = "clippy";
            extraArgs = ["--all-features"];
          };
          settings = {
            cargo = {
              allFeatures = true;
              loadOutDirsFromCheck = true;
              runBuildScripts = true;
            };
            checkOnSave = true;
            procMacro = {
              enable = true;
            };
          };
        };
      };

      crates-nvim = {
        enable = true;
        extraOptions = {
          autoload = true;
          autoupdate = true;
          loading_indicator = true;
          date_format = "%Y-%m-%d";
        };
      };

      lsp = {
        servers = {
          rust-analyzer = {
            enable = true;
            installCargo = true;
            installRustc = true;
            settings = {
              checkOnSave = true;
              check = {
                command = "clippy";
                extraArgs = ["--all-features"];
              };
              cargo = {
                allFeatures = true;
                loadOutDirsFromCheck = true;
                runBuildScripts = true;
              };
              procMacro = {
                enable = true;
              };
            };
          };
        };
      };
    };

    extraConfigLua = ''
      -- Rust-specific settings
      vim.api.nvim_create_autocmd("FileType", {
        pattern = "rust",
        callback = function()
          -- Set Rust indentation
          vim.opt_local.tabstop = 4
          vim.opt_local.shiftwidth = 4
          vim.opt_local.softtabstop = 4
          vim.opt_local.expandtab = true

          -- Set up inlay hints
          vim.cmd[[RustEnableInlayHints]]
        end
      })

      -- Configure Rust debugging
      local dap = require('dap')
      dap.adapters.lldb = {
        type = 'executable',
        command = 'lldb-vscode',
        name = 'lldb'
      }

      dap.configurations.rust = {
        {
          name = "Launch";
          type = "lldb";
          request = "launch";
          program = function()
            return vim.fn.input('Path to executable: ', vim.fn.getcwd() .. '/target/debug/', 'file')
          end;
          cwd = "''${workspaceFolder}";
          stopOnEntry = false;
          args = {};
          runInTerminal = false;
        },
      }
    '';

    keymaps = [
      {
        mode = "n";
        key = "<leader>rt";
        action = ":!cargo test<CR>";
        options = {
          silent = true;
          desc = "Run Rust tests";
        };
      }
      {
        mode = "n";
        key = "<leader>rr";
        action = ":!cargo run<CR>";
        options = {
          silent = true;
          desc = "Run Rust program";
        };
      }
      {
        mode = "n";
        key = "<leader>rb";
        action = ":!cargo build<CR>";
        options = {
          silent = true;
          desc = "Build Rust program";
        };
      }
      {
        mode = "n";
        key = "<leader>rc";
        action = ":!cargo check<CR>";
        options = {
          silent = true;
          desc = "Check Rust program";
        };
      }
      {
        mode = "n";
        key = "<leader>rf";
        action = ":!cargo fmt<CR>";
        options = {
          silent = true;
          desc = "Format Rust code";
        };
      }
    ];
  };
}
