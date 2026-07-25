-- herdr-splits.nvim — unified Ctrl+hjkl across Neovim splits and herdr panes.
--
-- Replaces nvim-tmux-navigation, which owned the same keys but crossed into
-- *tmux* panes. herdr is the multiplexer now, so those bindings were pointing
-- at the wrong thing: at a window edge they tried to reach a tmux pane that
-- isn't there.
--
-- This needs BOTH halves to work:
--   nvim side  — this file
--   herdr side — `herdr plugin install lmilojevicc/herdr-splits.nvim`
--                plus the [[keys.command]] blocks in home/development/herdr.nix
--                that bind ctrl+hjkl to the herdr-splits.* plugin actions.
-- Without the herdr half, movement stops dead at the outermost Neovim split.
--
-- `cond` keeps it inert outside a herdr pane (plain terminal, bare ssh), where
-- the herdr CLI it shells out to would not exist.
return {
  {
    "lmilojevicc/herdr-splits.nvim",
    cond = vim.env.HERDR_ENV == "1",
    event = "VeryLazy",
    opts = {
      -- at_edge = "wrap" would cycle back to the opposite pane; "stop" is less
      -- disorienting when several agents are open side by side.
      at_edge = "stop",
      nav_at_edge = "stop",
      -- Don't hijack the keys inside sidebars, pickers or terminal buffers —
      -- Ctrl+l in a terminal is "clear", and snacks pickers use hjkl.
      ignored_buftypes = { "nofile", "quickfix", "prompt", "help", "terminal" },
      ignored_filetypes = {
        "NvimTree",
        "neo-tree",
        "snacks_dashboard",
        "snacks_explorer",
        "snacks_picker",
        "Trouble",
        "trouble",
        "Outline",
        "aerial",
        "qf",
      },
    },
    keys = {
      { "<C-h>", function() require("herdr-splits").move_cursor_left() end, desc = "Go to left pane/split" },
      { "<C-j>", function() require("herdr-splits").move_cursor_down() end, desc = "Go to lower pane/split" },
      { "<C-k>", function() require("herdr-splits").move_cursor_up() end, desc = "Go to upper pane/split" },
      { "<C-l>", function() require("herdr-splits").move_cursor_right() end, desc = "Go to right pane/split" },
      { "<M-h>", function() require("herdr-splits").resize_left() end, desc = "Resize left" },
      { "<M-j>", function() require("herdr-splits").resize_down() end, desc = "Resize down" },
      { "<M-k>", function() require("herdr-splits").resize_up() end, desc = "Resize up" },
      { "<M-l>", function() require("herdr-splits").resize_right() end, desc = "Resize right" },
    },
  },
}
