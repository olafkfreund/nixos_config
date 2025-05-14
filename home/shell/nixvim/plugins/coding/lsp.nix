{
  config,
  lib,
  pkgs,
  ...
}: {
  config = {
    programs.nixvim = {
      plugins = {
        lsp = {
          enable = true;
          servers = {
            lua-ls.enable = true;
            nixd = {
              enable = true;
              settings.formatting.command = ["nixpkgs-fmt"];
            };
            pyright = {
              enable = true;
              settings.python.analysis = {
                typeCheckingMode = "basic";
                autoSearchPaths = true;
                useLibraryCodeForTypes = true;
                diagnosticMode = "workspace";
              };
            };
            gopls = {
              enable = true;
              settings = {
                usePlaceholders = true;
                analyses = {
                  unusedparams = true;
                  shadow = true;
                };
                staticcheck = true;
                linksInHover = false;
              };
            };
            rust-analyzer = {
              enable = true;
              settings = {
                checkOnSave = true;
                check = {
                  command = "clippy";
                };
              };
            };
          };
          keymaps = {
            diagnostic = {
              "<leader>j" = "goto_next";
              "<leader>k" = "goto_prev";
            };
            lspBuf = {
              "gd" = "definition";
              "gD" = "references";
              "gi" = "implementation";
              "gt" = "type_definition";
              "K" = "hover";
              "<leader>cr" = "rename";
              "<leader>ca" = "code_action";
              "<leader>cf" = "format";
            };
          };
        };

        lsp-format.enable = true;

        lspkind = {
          enable = true;
          mode = "symbol_text";
        };

        fidget = {
          enable = true;
          text = {
            spinner = "dots";
            done = "";
            commenced = "Started";
            completed = "Done";
          };
        };

        trouble = {
          enable = true;
          settings = {
            position = "bottom";
            height = 15;
            icons = true;
            mode = "workspace_diagnostics";
            fold_open = "";
            fold_closed = "";
            action_keys = {
              close = "q";
              cancel = "<esc>";
              refresh = "r";
              jump = "<cr>";
              toggle_fold = "zA";
              previous = "k";
              next = "j";
            };
            signs = {
              error = "";
              warning = "";
              hint = "";
              information = "";
              other = "";
            };
          };
        };
      };

      extraConfigLua = ''
        -- LSP Diagnostics Options
        local sign = function(opts)
          vim.fn.sign_define(opts.name, {
            texthl = opts.name,
            text = opts.text,
            numhl = ""
          })
        end

        sign({name = "DiagnosticSignError", text = "󰅚"})
        sign({name = "DiagnosticSignWarn", text = "⚠"})
        sign({name = "DiagnosticSignHint", text = "󰌶"})
        sign({name = "DiagnosticSignInfo", text = "ℹ"})

        vim.diagnostic.config({
          virtual_text = false,
          signs = true,
          update_in_insert = false,
          underline = true,
          severity_sort = true,
          float = {
            border = "rounded",
            source = "always",
            header = "",
            prefix = "",
          },
        })

        -- Fix border and float styling
        vim.lsp.handlers["textDocument/hover"] = vim.lsp.with(
          vim.lsp.handlers.hover,
          {border = "rounded"}
        )

        vim.lsp.handlers["textDocument/signatureHelp"] = vim.lsp.with(
          vim.lsp.handlers.signature_help,
          {border = "rounded"}
        )
      '';
    };
  };
}
