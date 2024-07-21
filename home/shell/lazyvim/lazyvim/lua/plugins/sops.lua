return {
  "lucidph3nx/nvim-sops",
  event = { "BufEnter" },
  opts = {
    -- your configuration comes here
    -- or leave it empty to use the default settings
    -- refer to the configuration section below
  },
  keys = {
    { "<leader>ef", vim.cmd.SopsEncrypt, desc = "[E]ncrypt [F]ile" },
    { "<leader>df", vim.cmd.SopsDecrypt, desc = "[D]ecrypt [F]ile" },
  },
}
