return {
  {
    "telescope.nvim",
    dependencies = {
      "kkharji/sqlite.lua",
      "nvim-telescope/telescope.nvim",
      config = function()
        require("telescope").load_extension("cheat")
      end,
    },
  },
}
