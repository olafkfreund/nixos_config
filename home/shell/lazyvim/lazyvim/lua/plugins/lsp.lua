return {
  -- Add nixd LSP configuration
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
              options = {
                enable = true,
                target = { "all" },
                offline = true,
                nixos = {
                  expr = "(builtins.getFlake (\"git+file://\" + toString /home/olafkfreund/.config/nixos)).nixosConfigurations.p620.options",
                },
                home_manager = {
                  expr = "(builtins.getFlake (\"git+file://\" + toString /home/olafkfreund/.config/nixos)).homeConfigurations.\"olafkfreund@p620\".options",
                },
              },
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
}
