require("nvim-treesitter.configs").setup({
	-- grammars are managed with nix
	auto_install = false,
	highlight = {
		enable = true,
	},
	indent = {
		emable = true,
	},
	incremental_selection = {
		enable = true,
		keymaps = {
			init_selection = "gnn", -- default mapping
			node_incremental = "v",
			node_decremental = "V",
		},
	},
	additional_vim_regex_highlighting = false,
})
-- Set folding method to expression
vim.o.foldmethod = "expr"

-- Set fold expression to use treesitter
vim.o.foldexpr = "nvim_treesitter#foldexpr()"
