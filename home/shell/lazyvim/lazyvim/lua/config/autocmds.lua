-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
-- Add any additional autocmds here

local autocmd = vim.api.nvim_create_autocmd
local augroup = vim.api.nvim_create_augroup

-- Gruvbox-compatible highlights for AI tools
local ai_augroup = augroup("AIHighlights", { clear = true })
autocmd("ColorScheme", {
  group = ai_augroup,
  callback = function()
    vim.api.nvim_set_hl(0, "AvanteOutput", { fg = "#fbf1c7", bg = "#3c3836" })
    vim.api.nvim_set_hl(0, "AvanteOutputBorder", { fg = "#8ec07c", bg = "NONE" })
  end,
})

-- AI tools file type specifics
autocmd("FileType", {
  pattern = { "AvanteInput", "AvanteOutput" },
  callback = function()
    vim.opt_local.tabstop = 2
    vim.opt_local.shiftwidth = 2
    vim.opt_local.spell = true
  end,
})
