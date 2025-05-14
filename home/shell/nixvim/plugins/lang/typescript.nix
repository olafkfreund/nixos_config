{
  pkgs,
  lib,
  ...
}: {
  programs.nixvim = {
    plugins = {
      treesitter = {
        grammarPackages = with pkgs.vimPlugins.nvim-treesitter.builtGrammars; [
          typescript
          tsx
          javascript
          jsdoc
        ];
      };

      lsp = {
        servers = {
          tsserver = {
            enable = true;
            extraOptions = {
              init_options = {
                preferences = {
                  includeInlayParameterNameHints = "all";
                  includeInlayPropertyDeclarationTypeHints = true;
                  includeInlayFunctionLikeReturnTypeHints = true;
                };
              };
            };
          };

          eslint = {
            enable = true;
            rootPatterns = [
              ".eslintrc.js"
              ".eslintrc.cjs"
              ".eslintrc.json"
              ".eslintrc"
              "package.json"
            ];
          };
        };
      };

      none-ls = {
        enable = true;
        sources = {
          formatting = {
            prettier.enable = true;
          };
          diagnostics = {
            eslint.enable = true;
          };
        };
      };
    };

    extraConfigLua = ''
      -- TypeScript specific settings
      vim.api.nvim_create_autocmd("FileType", {
        pattern = {"typescript", "typescriptreact", "javascript", "javascriptreact"},
        callback = function()
          -- Set TypeScript indentation
          vim.opt_local.tabstop = 2
          vim.opt_local.shiftwidth = 2
          vim.opt_local.softtabstop = 2
          vim.opt_local.expandtab = true

          -- Support for import suggestions
          vim.opt_local.path:append("node_modules")
          vim.opt_local.suffixesadd:append(".js,.jsx,.ts,.tsx")
        end
      })

      -- Import organization
      vim.api.nvim_create_autocmd("BufWritePre", {
        pattern = {"*.ts", "*.tsx", "*.js", "*.jsx"},
        callback = function()
          vim.lsp.buf.code_action({
            context = {
              only = { "source.organizeImports.ts" }
            },
            apply = true
          })
        end
      })
    '';

    # TypeScript specific keymaps
    keymaps = [
      {
        mode = "n";
        key = "<leader>ti";
        action = ":TypescriptAddMissingImports<CR>";
        options = {
          silent = true;
          desc = "Add missing imports";
        };
      }
      {
        mode = "n";
        key = "<leader>to";
        action = ":TypescriptOrganizeImports<CR>";
        options = {
          silent = true;
          desc = "Organize imports";
        };
      }
      {
        mode = "n";
        key = "<leader>tf";
        action = ":TypescriptFixAll<CR>";
        options = {
          silent = true;
          desc = "Fix all auto-fixable issues";
        };
      }
      {
        mode = "n";
        key = "<leader>tr";
        action = ":TypescriptRenameFile<CR>";
        options = {
          silent = true;
          desc = "Rename file and update imports";
        };
      }
    ];
  };
}
