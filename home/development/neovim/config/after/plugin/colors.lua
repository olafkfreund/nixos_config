vim.o.background = "dark"
require("gruvbox").setup({
	undercurl = true,
	underline = true,
	bold = false,
	-- italic = {
	--   strings = true,
	--   comments = true,
	--   operators = false,
	--   folds = true,
	-- },
	strikethrough = true,
	invert_selection = false,
	invert_signs = false,
	invert_tabline = false,
	invert_intend_guides = false,
	inverse = true, -- invert background for search, diffs, statuslines and errors
	contrast = "hard", -- can be "hard", "soft" or empty string
	dim_inactive = false,
	transparent_mode = false,
})
vim.cmd.colorscheme("gruvbox")
-- TODO: undercurl for diagnostics
