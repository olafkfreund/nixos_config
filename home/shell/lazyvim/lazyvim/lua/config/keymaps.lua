-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

-- Open the AI/Claude Code cheatsheet shipped alongside this config.
vim.keymap.set("n", "<leader>?C", function()
  vim.cmd.edit(vim.fn.stdpath("config") .. "/AI-CHEATSHEET.md")
end, { desc = "Open AI cheatsheet" })
