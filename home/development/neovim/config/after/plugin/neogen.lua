require("neogen").setup({
	enabled = true,
	snippet_engine = "luasnip",
	languages = {
		python = {
			template = {
				annotation_convention = "reST",
			},
		},
	},
})

local opts = { noremap = true, silent = true }
vim.api.nvim_set_keymap("n", "<leader>ann", ":lua require('neogen').generate()<CR>", opts)
vim.api.nvim_set_keymap("n", "<leader>anc", ":lua require('neogen').generate({ type = 'class' })<CR>", opts)
vim.api.nvim_set_keymap("n", "<leader>anf", ":lua require('neogen').generate({ type = 'func' })<CR>", opts)
