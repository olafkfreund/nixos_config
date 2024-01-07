require("lualine").setup({
	options = {
		icons_enabled = true,
		theme = "auto",
		-- component_separators = { left = "", right = "" },
		-- section_separators = { left = "", right = "" },
		disabled_filetypes = {
			statusline = {},
			winbar = {},
		},
		ignore_focus = {},
		always_divide_middle = true,
		globalstatus = true,
		refresh = {
			statusline = 1000,
			tabline = 1000,
			winbar = 1000,
		},
	},
	sections = {
		lualine_a = { "mode" },
		lualine_b = {
			"branch",
			{
				"diff",
				colored = true, -- Displays a colored diff status if set to true
				diff_color = {
					-- Same color values as the general color option can be used here.
					added = "DiffAdd", -- Changes the diff's added color
					modified = "DiffChange", -- Changes the diff's modified color
					removed = "DiffDelete", -- Changes the diff's removed color you
				},
				symbols = { added = "+", modified = "~", removed = "-" }, -- Changes the symbols used by the diff.
				source = nil, -- A function that works as a data source for diff.
				-- It must return a table as such:
				--   { added = add_count, modified = modified_count, removed = removed_count }
				-- or nil on failure. count <= 0 won't be displayed.
			},
			{
				"diagnostics",

				-- Table of diagnostic sources, available sources are:
				--   'nvim_lsp', 'nvim_diagnostic', 'nvim_workspace_diagnostic', 'coc', 'ale', 'vim_lsp'.
				-- or a function that returns a table as such:
				--   { error=error_cnt, warn=warn_cnt, info=info_cnt, hint=hint_cnt }
				sources = { "nvim_lsp" },

				-- Displays diagnostics for the defined severity types
				sections = { "error", "warn", "info", "hint" },

				diagnostics_color = {
					-- Same values as the general color option can be used here.
					error = "DiagnosticError", -- Changes diagnostics' error color.
					warn = "DiagnosticWarn", -- Changes diagnostics' warn color.
					info = "DiagnosticInfo", -- Changes diagnostics' info color.
					hint = "DiagnosticHint", -- Changes diagnostics' hint color.
				},
				symbols = { error = "E", warn = "W", info = "I", hint = "H" },
				colored = true, -- Displays diagnostics status in color if set to true.
				update_in_insert = false, -- Update diagnostics in insert mode.
				always_visible = false, -- Show diagnostics even if there are none.
			},
		},
		lualine_c = {
			{
				"filename",
				file_status = true, -- Displays file status (readonly status, modified status)
				newfile_status = true, -- Display new file status (new file means no write after created)
				path = 1, -- 0: Just the filename
				-- 1: Relative path
				-- 2: Absolute path
				-- 3: Absolute path, with tilde as the home directory
				-- 4: Filename and parent dir, with tilde as the home directory

				shorting_target = 40, -- Shortens path to leave 40 spaces in the window
				-- for other components.
				symbols = {
					modified = "[+]", -- Text to show when the file is modified.
					readonly = "[-]", -- Text to show when the file is non-modifiable or readonly.
					unnamed = "[No Name]", -- Text to show for unnamed buffers.
					newfile = "[New]", -- Text to show for newly created file before first write
				},
			},
			{
				"buffers",
				show_filename_only = true, -- Shows shortened relative path when set to false.
				hide_filename_extension = false, -- Hide filename extension when set to true.
				show_modified_status = true, -- Shows indicator when the buffer is modified.

				mode = 0, -- 0: Shows buffer name
				-- 1: Shows buffer index
				-- 2: Shows buffer name + buffer index
				-- 3: Shows buffer number
				-- 4: Shows buffer name + buffer number

				max_length = vim.o.columns * 2 / 3, -- Maximum width of buffers component,
				-- it can also be a function that returns
				-- the value of `max_length` dynamically.
				filetype_names = {
					TelescopePrompt = "Telescope",
					dashboard = "Dashboard",
					packer = "Packer",
					fzf = "FZF",
					alpha = "Alpha",
				}, -- Shows specific buffer name for that filetype ( { `filetype` = `buffer_name`, ... } )

				-- Automatically updates active buffer color to match color of other components (will be overidden if buffers_color is set)
				use_mode_colors = false,

				buffers_color = {
					-- Same values as the general color option can be used here.
					active = "lualine_c_normal", -- Color for active buffer.
					inactive = "lualine_c_inactive", -- Color for inactive buffer.
				},

				symbols = {
					modified = " ●", -- Text to show when the buffer is modified
					alternate_file = "#", -- Text to show to identify the alternate file
					directory = "", -- Text to show when the buffer is a directory
				},
			},
		},
		lualine_x = {
			"encoding",
			{
				"fileformat",
				symbols = {
					unix = "", -- e712
					dos = "", -- e70f
					mac = "", -- e711
				},
			},
			{
				"filetype",
				colored = true, -- Displays filetype icon in color if set to true
				icon_only = false, -- Display only an icon for filetype
				icon = { align = "right" }, -- Display filetype icon on the right hand side
				-- icon =    {'X', align='right'}
				-- Icon string ^ in table is ignored in filetype component
			},
		},
		lualine_y = { "progress" },
		lualine_z = { "location" },
	},
	inactive_sections = {
		lualine_a = {},
		lualine_b = {},
		lualine_c = { "filename" },
		lualine_x = { "location" },
		lualine_y = {},
		lualine_z = {},
	},
	-- TODO: configure tabline/winbar
	-- tabline = {
	-- 	lualine_a = {
	-- 		{
	-- 			"tabs",
	-- 			max_length = vim.o.columns / 3, -- Maximum width of tabs component.
	-- 			-- Note:
	-- 			-- It can also be a function that returns
	-- 			-- the value of `max_length` dynamically.
	-- 			mode = 2, -- 0: Shows tab_nr
	-- 			-- 1: Shows tab_name
	-- 			-- 2: Shows tab_nr + tab_name
	--
	-- 			-- Automatically updates active tab color to match color of other components (will be overidden if buffers_color is set)
	-- 			use_mode_colors = false,
	--
	-- 			-- tabs_color = {
	-- 			-- 	-- Same values as the general color option can be used here.
	-- 			-- 	active = "lualine_{section}_normal", -- Color for active tab.
	-- 			-- 	inactive = "lualine_{section}_inactive", -- Color for inactive tab.
	-- 			-- },
	--
	-- 			fmt = function(name, context)
	-- 				-- Show + if buffer is modified in tab
	-- 				local buflist = vim.fn.tabpagebuflist(context.tabnr)
	-- 				local winnr = vim.fn.tabpagewinnr(context.tabnr)
	-- 				local bufnr = buflist[winnr]
	-- 				local mod = vim.fn.getbufvar(bufnr, "&mod")
	--
	-- 				return name .. (mod == 1 and " +" or "")
	-- 			end,
	-- 		},
	-- 	},
	-- },
	-- winbar = {
	-- 	lualine_a = {
	-- 		{
	-- 			"windows",
	-- 			show_filename_only = true, -- Shows shortened relative path when set to false.
	-- 			show_modified_status = true, -- Shows indicator when the window is modified.
	--
	-- 			mode = 0, -- 0: Shows window name
	-- 			-- 1: Shows window index
	-- 			-- 2: Shows window name + window index
	--
	-- 			max_length = vim.o.columns * 2 / 3, -- Maximum width of windows component,
	-- 			-- it can also be a function that returns
	-- 			-- the value of `max_length` dynamically.
	-- 			filetype_names = {
	-- 				TelescopePrompt = "Telescope",
	-- 				dashboard = "Dashboard",
	-- 				packer = "Packer",
	-- 				fzf = "FZF",
	-- 				alpha = "Alpha",
	-- 			}, -- Shows specific window name for that filetype ( { `filetype` = `window_name`, ... } )
	--
	-- 			disabled_buftypes = { "quickfix", "prompt" }, -- Hide a window if its buffer's type is disabled
	--
	-- 			-- Automatically updates active window color to match color of other components (will be overidden if buffers_color is set)
	-- 			use_mode_colors = false,
	--
	-- 			-- windows_color = {
	-- 			-- 	-- Same values as the general color option can be used here.
	-- 			-- 	active = "lualine_{section}_normal", -- Color for active window.
	-- 			-- 	inactive = "lualine_{section}_inactive", -- Color for inactive window.
	-- 			-- },
	-- 		},
	-- 	},
	-- },
	inactive_winbar = {},
	extensions = { "nvim-tree" },
})
