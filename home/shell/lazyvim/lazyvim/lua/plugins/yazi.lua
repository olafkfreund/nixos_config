return {
  {
    "mikavilpas/yazi.nvim",
    event = "VeryLazy",
    keys = {
      { "<leader>gy", "<cmd>Yazi<CR>", desc = "Open Yazi (current file)" },
      { "<leader>gY", "<cmd>Yazi cwd<CR>", desc = "Open Yazi (cwd)" },
    },
    opts = {
      open_for_directories = false,
    },
  },
}
