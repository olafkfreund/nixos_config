return {
  {
    "telescope.nvim",
    dependencies = {
      "mrcjkb/telescope-manix",
      config = function()
        require("telescope").load_extension("manix")
      end,
    },
  },
}
