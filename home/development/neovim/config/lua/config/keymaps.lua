vim.g.mapleader = " "
vim.keymap.set(
	"n",
	"<m-h>",
	":TmuxNavigateLeft<cr>",
	{ noremap = true, silent = true, desc = "Move left with tmux-navigator" }
)
vim.keymap.set(
	"n",
	"<m-j>",
	":TmuxNavigateDown<cr>",
	{ noremap = true, silent = true, desc = "Move down with tmux-navigator" }
)
vim.keymap.set(
	"n",
	"<m-k>",
	":TmuxNavigateUp<cr>",
	{ noremap = true, silent = true, desc = "Move up with tmux-navigator" }
)
vim.keymap.set(
	"n",
	"<m-l>",
	":TmuxNavigateRight<cr>",
	{ noremap = true, silent = true, desc = "Move right with tmux-navigator" }
)

vim.keymap.set("v", "p", '"_dP', { noremap = true, desc = "Paste without yanking" })
vim.keymap.set({ "n", "v" }, "<leader>y", '"+y', { noremap = true, desc = "Yank into system clipboard" })

vim.keymap.set("v", "J", ":m '>+1<CR>gv=gv", { desc = "Move selection up" })
vim.keymap.set("v", "K", ":m '<-1<CR>gv=gv", { desc = "Move selection down" })

vim.keymap.set("n", "<C-d>", "<C-d>zz", { desc = "Move down and keep cursor in the middle" })
vim.keymap.set("n", "<C-u>", "<C-u>zz", { desc = "Move up and keep cursor in the middle" })

vim.keymap.set("n", "n", "nzzzv", { desc = "Next result in the middle of the screen" })
vim.keymap.set("n", "N", "Nzzzv", { desc = "Previous result in the middle of the screen" })
