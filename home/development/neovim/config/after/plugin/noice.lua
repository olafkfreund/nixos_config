require("noice").setup({
	routes = {
		{
			filter = {
				event = "msg_show",
				kind = "",
				find = "written",
			},
			opts = { skip = true },
		},
	},
	views = {
		cmdline_popup = {
			border = {
				style = "none",
				padding = { 1, 3 },
			},
			filter_options = {},
			win_options = {
				winhighlight = "NormalFloat:NormalFloat,FloatBorder:FloatBorder",
			},
		},
	},
	lsp = {
		message = {
			enabled = false,
		},
		override = {
			-- override markdown rendering so that **cmp** and other plugins use **Treesitter**
			["vim.lsp.util.convert_input_to_markdown_lines"] = true,
			["vim.lsp.util.stylize_markdown"] = true,
			["cmp.entry.get_documentation"] = true,
		},
	},

	cmdline = {
		view = "cmdline_popup",
	},

	presets = {
		bottom_search = true,       -- use a classic bottom cmdline for search
		long_message_to_split = true, -- long messages will be sent to a split
		inc_rename = true,          -- enables an input dialog for inc-rename.nvim
		lsp_doc_border = true,      -- add a border to hover docs and signature help
	},
})
