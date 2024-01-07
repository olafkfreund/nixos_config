require("nvim-tree").setup({
	hijack_netrw = true,
	hijack_cursor = true,
	sort_by = "case_sensitive",
	view = {
		width = 50,
	},
	renderer = {
		group_empty = true,
	},
	sync_root_with_cwd = true,
	reload_on_bufenter = true,
	update_focused_file = {
		enable = true,
	},
	filters = {
		dotfiles = false,
	},
})

local api = require("nvim-tree.api")
vim.keymap.set("n", "<C-f>", api.tree.toggle, { desc = "nvim-tree toggle" })
