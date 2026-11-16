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
-- `cond` keeps it inert outside a herdr pane (plain terminal, bare ssh).
local ignored_buftypes = { "nofile", "quickfix", "prompt", "help", "terminal" }
local ignored_filetypes = {
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
}
local keys = { left = "h", down = "j", up = "k", right = "l" }

local function ignored()
  return vim.tbl_contains(ignored_buftypes, vim.bo.buftype) or vim.tbl_contains(ignored_filetypes, vim.bo.filetype)
end

-- Not an <expr> mapping: these change windows, which textlock forbids there.
local function passthrough(key)
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(key, true, false, true), "n", false)
end

local function nav(dir)
  if vim.env.HERDR_ENV == "1" then
    require("herdr-splits")["move_cursor_" .. dir]()
  elseif ignored() then
    passthrough("<C-" .. keys[dir] .. ">")
  else
    local before = vim.fn.winnr()
    vim.cmd("wincmd " .. keys[dir])
    if vim.fn.winnr() == before then
      vim.fn.jobstart({ "herdr-app", "do", "pane.go", "--direction", dir })
    end
  end
end

local function size(dir)
  if vim.env.HERDR_ENV == "1" then
    require("herdr-splits")["resize_" .. dir]()
  elseif ignored() then
    passthrough("<M-" .. keys[dir] .. ">")
  else
    local horizontal = dir == "left" or dir == "right"
    local neighbor = vim.fn.winnr(horizontal and "l" or "j") ~= vim.fn.winnr()
    local grow = neighbor == (dir == "right" or dir == "down")
    vim.cmd((horizontal and "vertical resize " or "resize ") .. (grow and "+" or "-") .. 3 * vim.v.count1)
  end
end

return {
  {
    "lmilojevicc/herdr-splits.nvim",
    cond = vim.env.HERDR_ENV == "1" or vim.env.HC_TERMINAL_ID ~= nil,
    event = "VeryLazy",
    config = function(_, opts)
      if vim.env.HERDR_ENV == "1" then
        require("herdr-splits").setup(opts)
      end
    end,
    opts = {
      -- at_edge = "wrap" would cycle back to the opposite pane; "stop" is less
      -- disorienting when several agents are open side by side.
      at_edge = "stop",
      nav_at_edge = "stop",
      -- Don't hijack the keys inside sidebars, pickers or terminal buffers —
      -- Ctrl+l in a terminal is "clear", and snacks pickers use hjkl.
      ignored_buftypes = ignored_buftypes,
      ignored_filetypes = ignored_filetypes,
    },
    keys = {
      {
        "<C-h>",
        function()
          nav("left")
        end,
        desc = "Go to left pane/split",
      },
      {
        "<C-j>",
        function()
          nav("down")
        end,
        desc = "Go to lower pane/split",
      },
      {
        "<C-k>",
        function()
          nav("up")
        end,
        desc = "Go to upper pane/split",
      },
      {
        "<C-l>",
        function()
          nav("right")
        end,
        desc = "Go to right pane/split",
      },
      {
        "<M-h>",
        function()
          size("left")
        end,
        desc = "Resize left",
      },
      {
        "<M-j>",
        function()
          size("down")
        end,
        desc = "Resize down",
      },
      {
        "<M-k>",
        function()
          size("up")
        end,
        desc = "Resize up",
      },
      {
        "<M-l>",
        function()
          size("right")
        end,
        desc = "Resize right",
      },
    },
  },
}
