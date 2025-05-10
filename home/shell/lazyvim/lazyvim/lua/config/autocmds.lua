-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
-- Add any additional autocmds here

-- Define autocmds here to keep config clean
local autocmd = vim.api.nvim_create_autocmd
local augroup = vim.api.nvim_create_augroup

-- Create Copilot highlight groups that match your Gruvbox theme
local copilot_augroup = augroup("Copilot", { clear = true })
autocmd("ColorScheme", {
  group = copilot_augroup,
  callback = function()
    -- Create highlights compatible with Gruvbox for Copilot
    vim.api.nvim_set_hl(0, "CmpItemKindCopilot", { fg = "#8ec07c", bg = "NONE" })
    vim.api.nvim_set_hl(0, "CopilotSuggestion", { fg = "#665c54", bg = "NONE" })

    -- Highlight for Avante.nvim using Copilot
    vim.api.nvim_set_hl(0, "AvanteOutput", { fg = "#fbf1c7", bg = "#3c3836" })
    vim.api.nvim_set_hl(0, "AvanteOutputBorder", { fg = "#8ec07c", bg = "NONE" })
  end,
})

-- AI tools file type specifics
autocmd("FileType", {
  pattern = { "AvanteInput", "AvanteOutput" },
  callback = function()
    -- Set smaller indentation for AI responses
    vim.opt_local.tabstop = 2
    vim.opt_local.shiftwidth = 2
    -- Enable spell checking in AI prompts
    vim.opt_local.spell = true
  end,
})
