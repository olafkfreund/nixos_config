{
  pkgs,
  ...
}: {
  programs.nixvim = {
    plugins = {
      lsp = {
        enable = true;

        servers = {
          # Nix language server
          nixd.enable = true;

          # Lua language server
          lua-ls = {
            enable = true;
            settings.telemetry.enable = false;
          };

          # Typescript/JavaScript language server
          tsserver.enable = true;

          # JSON language server
          jsonls.enable = true;

          # YAML language server with enhanced settings
          yamlls = {
            enable = true;
            settings = {
              yaml = {
                keyOrdering = false;
                format = {
                  enable = true;
                };
                schemas = {
                  kubernetes = "*.yaml";
                  "http://json.schemastore.org/github-workflow" = ".github/workflows/*.{yml,yaml}";
                  "http://json.schemastore.org/github-action" = ".github/action.{yml,yaml}";
                  "http://json.schemastore.org/ansible-stable-2.9" = "roles/tasks/*.{yml,yaml}";
                  "http://json.schemastore.org/prettierrc" = ".prettierrc.{yml,yaml}";
                  "http://json.schemastore.org/kustomization" = "kustomization.{yml,yaml}";
                  "http://json.schemastore.org/chart" = "Chart.{yml,yaml}";
                  "https://json.schemastore.org/helmfile" = "helmfile.{yml,yaml}";
                  "https://json.schemastore.org/dockerfile" = "*Dockerfile*";
                };
                validate = true;
                completion = true;
              };
            };
          };

          # Bash language server with enhanced settings
          bashls = {
            enable = true;
            filetypes = ["sh" "bash" "zsh"];
            settings = {
              includeAllWorkspaceSymbols = true;
              useGitHubCopilotIgnore = true;
              shellcheckPath = "${pkgs.shellcheck}/bin/shellcheck";
            };
          };

          # Python language server with enhanced settings
          pyright = {
            enable = true;
            settings = {
              python = {
                analysis = {
                  autoSearchPaths = true;
                  diagnosticMode = "workspace";
                  useLibraryCodeForTypes = true;
                  typeCheckingMode = "basic";
                };
              };
            };
          };

          # Rust language server
          rust-analyzer = {
            enable = true;
            installRustc = false;
            installCargo = false;
          };

          # Go language server with enhanced settings
          gopls = {
            enable = true;
            settings = {
              usePlaceholders = true;
              analyses = {
                unusedparams = true;
                fieldalignment = true;
              };
              staticcheck = true;
              gofumpt = true;
            };
          };

          # Terraform language server
          terraformls = {
            enable = true;
            settings = {
              experimentalFeatures = {
                validateOnSave = true;
                prefillRequiredFields = true;
              };
              terraform = {
                languageServer = {
                  external = true;
                };
              };
            };
          };

          # Just language server (for Justfiles)
          # Using nil_ls as justls is not available in nixpkgs
          nil_ls = {
            enable = true;
            # Adding just to supported file types
            filetypes = ["nix" "just"];
          };

          # Zsh language server - using bash-language-server for Zsh files
          # We already configured bashls to include zsh files above
        };

        keymaps = {
          lspBuf = {
            # Displays hover information about the symbol under the cursor
            "K" = "hover";

            # Jump to the definition
            "gd" = "definition";

            # Jump to declaration
            "gD" = "declaration";

            # Lists all the implementations for the symbol under the cursor
            "gi" = "implementation";

            # Jumps to the definition of the type symbol
            "go" = "type_definition";

            # Lists all the references
            "gr" = "references";

            # Displays a function's signature information
            "<C-k>" = "signature_help";

            # Renames all references to the symbol under the cursor
            "<leader>lr" = "rename";

            # Format code
            "<leader>lf" = "format";

            # Selects a code action available at the current cursor position
            "<leader>la" = "code_action";

            # Show diagnostics for current line
            "<leader>ll" = "document_diagnostics";

            # Show diagnostics for workspace
            "<leader>lw" = "workspace_diagnostics";
          };

          diagnostic = {
            # Navigate to previous diagnostic in buffer
            "[d" = "goto_prev";

            # Navigate to next diagnostic in buffer
            "]d" = "goto_next";

            # Show diagnostics for line
            "<leader>e" = "open_float";

            # Show diagnostics for buffer in quickfix list
            "<leader>q" = "setloclist";
          };
        };
      };

      # Add nvim-lspconfig for advanced configuration
      lspkind = {
        enable = true;
        cmp = {
          enable = true;
          menu = {
            nvim_lsp = "[LSP]";
            nvim_lua = "[Lua]";
            path = "[Path]";
            buffer = "[Buffer]";
            copilot = "[AI]";
            luasnip = "[Snippet]";
          };
        };
      };

      # Enhancements to the LSP experience
      lsp-lines = {
        enable = true;
        currentLine = true;
      };

      # Signature help
      lsp-signature = {
        enable = true;
        hideOnInsertLeave = true;
        floatingWindowStyle = "rounded";
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

      -- Customize LSP floating window borders
      require("lspconfig.ui.windows").default_options.border = "rounded"

      -- Additional file type associations for LSP servers
      vim.filetype.add({
        pattern = {
          [".*%.tf"] = "terraform",
          [".*%.tfvars"] = "terraform",
          ["Justfile"] = "just",
          ["justfile"] = "just",
          [".*%.just"] = "just",
        },
      })
    '';
  };
}
