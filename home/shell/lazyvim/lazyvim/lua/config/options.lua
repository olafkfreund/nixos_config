-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- Terminal and escape key handling
vim.opt.timeout = true
vim.opt.timeoutlen = 300
vim.opt.ttimeoutlen = 0 -- Remove delay for escape sequences

-- ── Alien HUD chrome ───────────────────────────────────────────────
-- winborder (Neovim 0.11+) is the global default border for every floating
-- window, so LSP hover, diagnostics, rename, and any plugin float that does
-- not force its own style get the plates' square single-line box from one
-- setting instead of a per-plugin `border = ...` hunt.
vim.o.winborder = "single"

-- Split seams as hairline rules, and no "~" filler past the last line —
-- the plates draw empty panel space as empty, not as a ragged column.
vim.opt.fillchars:append({
  eob = " ",
  vert = "│",
  horiz = "─",
  horizup = "┴",
  horizdown = "┬",
  vertleft = "┤",
  vertright = "├",
  verthoriz = "┼",
  fold = " ",
  foldopen = "▾",
  foldclose = "▸",
  foldsep = " ",
})

-- Opaque floats: the HUD panels are solid boxes over the plate, and any
-- blend lets the text behind bleed through and muddies the phosphor green.
vim.opt.winblend = 0
vim.opt.pumblend = 0

vim.opt.cursorline = true
