local Hydra = require("hydra")
local gitsigns = require("gitsigns")

Hydra({
	name = "Git",
	config = {
		color = "pink",
		invoke_on_body = true,
		hint = {
			border = "rounded",
		},
		on_enter = function()
			vim.cmd("mkview")
			vim.cmd("silent! %foldopen!")
			vim.bo.modifiable = false
			gitsigns.toggle_signs(true)
			gitsigns.toggle_numhl(true)
			gitsigns.toggle_current_line_blame(true)
			gitsigns.toggle_linehl(true)
			gitsigns.toggle_deleted(true)
		end,
		on_exit = function()
			local cursor_pos = vim.api.nvim_win_get_cursor(0)
			vim.cmd("loadview")
			vim.api.nvim_win_set_cursor(0, cursor_pos)
			vim.cmd("normal zv")
			gitsigns.toggle_signs(false)
			gitsigns.toggle_numhl(false)
			gitsigns.toggle_current_line_blame(false)
			gitsigns.toggle_linehl(false)
			gitsigns.toggle_deleted(false)
		end,
	},
	mode = { "n", "x" },
	body = "<leader>g",
	heads = {
		{
			"J",
			function()
				if vim.wo.diff then
					return "]c"
				end
				vim.schedule(function()
					gitsigns.next_hunk()
				end)
				return "<Ignore>"
			end,
			{ expr = true, desc = "next hunk" },
		},
		{
			"K",
			function()
				if vim.wo.diff then
					return "[c"
				end
				vim.schedule(function()
					gitsigns.prev_hunk()
				end)
				return "<Ignore>"
			end,
			{ expr = true, desc = "prev hunk" },
		},
		{ "s", gitsigns.stage_hunk,      { silent = true, desc = "Stage hunk" } },
		{ "S", gitsigns.stage_buffer,    { desc = "Stage buffer" } },
		{ "r", gitsigns.reset_hunk,      { silent = true, desc = "Reset hunk" } },
		{ "R", gitsigns.reset_buffer,    { silent = true, desc = "Reset buffer" } },
		{ "u", gitsigns.undo_stage_hunk, { desc = "Unstage hunk" } },
		{ "p", gitsigns.preview_hunk,    { desc = "Preview hunk" } },
		{ "d", gitsigns.diffthis,        { nowait = true, desc = "Diff" } },
		{
			"B",
			function()
				gitsigns.blame_line({ full = true })
			end,
			{ desc = "blame show full" },
		},
		{ "/", gitsigns.show, { exit = true, desc = "show base file" } }, -- show the base of the file
		-- { "<Enter>", "<Cmd>Neogit<CR>", { exit = true, desc = "Neogit" } },
		{ "q", nil,           { exit = true, nowait = true, desc = "exit" } },
	},
})

Hydra({
	name = "WindowManage",
	config = {
		color = "pink",
		invoke_on_body = true,
		hint = {
			border = "rounded",
		},
	},
	mode = { "n", "x" },
	body = "<leader>w",
	heads = {
		{ "<esc>", nil, { exit = true, nowait = true, desc = "exit" } },
		{
			"h",
			function()
				vim.cmd("wincmd h")
			end,
			{ nowait = true, desc = "Move to left window" },
		},
		{
			"j",
			function()
				vim.cmd("wincmd j")
			end,
			{ nowait = true, desc = "Move to window below" },
		},
		{
			"k",
			function()
				vim.cmd("wincmd k")
			end,
			{ nowait = true, desc = "Move to window above" },
		},
		{
			"l",
			function()
				vim.cmd("wincmd l")
			end,
			{ nowait = true, desc = "Move to right window" },
		},

		-- Window resizing
		{
			"+",
			function()
				vim.cmd("resize +5")
			end,
			{ nowait = true, desc = "Increase height" },
		},
		{
			"-",
			function()
				vim.cmd("resize -5")
			end,
			{ nowait = true, desc = "Decrease height" },
		},
		{
			"<",
			function()
				vim.cmd("vertical resize -5")
			end,
			{ nowait = true, desc = "Decrease width" },
		},
		{
			">",
			function()
				vim.cmd("vertical resize +5")
			end,
			{ nowait = true, desc = "Increase width" },
		},

		-- Split management
		{
			"s",
			function()
				vim.cmd("split")
			end,
			{ nowait = true, desc = "Split horizontally" },
		},
		{
			"v",
			function()
				vim.cmd("vsplit")
			end,
			{ nowait = true, desc = "Split vertically" },
		},
		{
			"q",
			function()
				vim.cmd("close")
			end,
			{ nowait = true, desc = "Close current window" },
		},

		-- Tab management
		{
			"t",
			function()
				vim.cmd("tabnew")
			end,
			{ nowait = true, exit = true, desc = "New tab" },
		},
		{
			"T",
			function()
				vim.cmd("tabclose")
			end,
			{ nowait = true, exit = true, desc = "Close current tab" },
		},
		-- barbar.nvim keymaps
		{
			"n",
			function()
				vim.cmd("BufferPrevious")
			end,
			{ nowait = true, desc = "Next buffer" },
		},
		{
			"p",
			function()
				vim.cmd("BufferNext")
			end,
			{ nowait = true, desc = "Previous buffer" },
		},
	},
})
