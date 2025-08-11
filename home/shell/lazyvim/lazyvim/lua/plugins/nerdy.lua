return {
  {
    "2kabhishek/nerdy.nvim",
    dependencies = {
      "stevearc/dressing.nvim",
      "nvim-telescope/telescope.nvim",
    },
    cmd = "Nerdy",
    keys = {
      { "<leader>N", "<cmd>Nerdy<CR>", desc = "Pick icon" },
    },
    config = function()
      -- Ensure clean setup
      require("nerdy").setup()
    end,
  },
}
