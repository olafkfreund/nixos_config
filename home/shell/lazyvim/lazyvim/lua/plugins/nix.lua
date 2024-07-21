return {
  {
    "nvim-treesitter/nvim-treesitter",
    opts = { ensure_installed = { "nix" } },
  },
  {
    "neovim/nvim-lspconfig",
    name = "lspconfig.nil_ls",
    ft = { "nix" },
    opts = {},
    config = function(_, opts)
      require("lspconfig").nil_ls.setup(opts)
    end,
  },
  {
    "neovim/nvim-lspconfig",
    name = "lspconfig.nixd",
    ft = { "nix" },
    opts = {},
    config = function(_, opts)
      require("lspconfig").nixd.setup(opts)
    end,
  },
  {
    "stevearc/conform.nvim",
    optional = true,
    opts = {
      formatters_by_ft = {
        nix = { "nixfmt" },
      },
    },
  },
  {
    "figsoda/nix-develop.nvim",
    event = "VeryLazy",
  },
}
