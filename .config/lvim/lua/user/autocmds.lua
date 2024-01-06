vim.api.nvim_create_autocmd("BufWritePre", {
  pattern = { ".config/lvim/config.lua" },
  command = "PackerCompile",
})
