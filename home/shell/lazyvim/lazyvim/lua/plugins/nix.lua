return {
  -- Treesitter for Nix syntax
  {
    "nvim-treesitter/nvim-treesitter",
    opts = { ensure_installed = { "nix" } },
  },

  -- Nix LSP via nixd (single, comprehensive Nix LSP)
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        nixd = {
          settings = {
            nixd = {
              formatting = {
                command = { "alejandra" },
                timeout_ms = 5000,
              },
              options = (function()
                local host = vim.fn.hostname()
                local flake = '(builtins.getFlake ("git+file://" + toString /home/olafkfreund/.config/nixos))'
                return {
                  enable = true,
                  target = { "all" },
                  offline = true,
                  nixos = {
                    expr = flake .. ".nixosConfigurations." .. host .. ".options",
                  },
                }
              end)(),
              diagnostics = {
                enable = true,
                ignored = {},
                excluded = {
                  "\\.direnv",
                  "result",
                  "\\.git",
                  "node_modules",
                },
              },
              eval = {
                depth = 2,
                workers = 3,
                trace = {
                  server = "off",
                  evaluation = "off",
                },
              },
              completion = {
                enable = true,
                priority = 10,
                insertSingleCandidateImmediately = true,
              },
              path = {
                include = { "**/*.nix" },
                exclude = {
                  ".direnv/**",
                  "result/**",
                  ".git/**",
                  "node_modules/**",
                },
              },
              lsp = {
                progressBar = true,
                snippets = true,
                logLevel = "info",
                maxIssues = 100,
                failureHandling = {
                  retry = {
                    max = 3,
                    delayMs = 1000,
                  },
                  fallbackToOffline = true,
                },
              },
            },
          },
        },
      },
    },
  },

  -- Nix formatter via conform
  {
    "stevearc/conform.nvim",
    optional = true,
    opts = {
      formatters_by_ft = {
        nix = { "nixfmt" },
      },
    },
  },

  -- Nix develop integration
  {
    "figsoda/nix-develop.nvim",
    event = "VeryLazy",
  },
}
