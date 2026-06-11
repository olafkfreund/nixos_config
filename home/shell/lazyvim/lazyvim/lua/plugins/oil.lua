-- oil.nvim — edit the filesystem like a buffer. Kept as a secondary explorer
-- (not the default) because it's the surface claudecode.nvim hooks for
-- @-mentioning files/dirs into Claude. `-` opens the parent dir.
return {
  {
    "stevearc/oil.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    lazy = false,
    opts = {
      default_file_explorer = false, -- leave snacks/neo-tree as the primary tree
      view_options = { show_hidden = true },
      skip_confirm_for_simple_edits = false,
    },
    keys = {
      { "-", "<cmd>Oil<cr>", desc = "Open parent dir (oil)" },
    },
  },
}
