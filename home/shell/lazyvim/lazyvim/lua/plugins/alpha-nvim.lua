-- Start screen as a Weyland-Yutani panel: boxed masthead, bracketed
-- shortcut keys, and a subsystem-style status footer. Replaces the stock
-- Neovim block logo (and the ~100 lines of per-character highlight ranges
-- it needed) — the plates are drawn with box rules, not filled glyphs.
--
-- Highlight groups (AlphaHeader / AlphaButtons / AlphaShortcut / AlphaFooter)
-- are defined in the generated lua/plugins/colorscheme.lua so the palette
-- stays in one place.
return {
  {
    "goolord/alpha-nvim",
    event = "VimEnter",
    enabled = true,
    init = false,
    opts = function()
      local dashboard = require("alpha.themes.dashboard")

      -- The Weyland-Yutani asset placard, drawn in text. Deliberately not the
      -- PNG: real image rendering needs the kitty graphics protocol, which
      -- does not survive tmux or herdr — where this editor actually runs — so
      -- the placard is redrawn with box characters and works everywhere.
      -- Column-aligned by construction; keep every line 64 cells wide.
      dashboard.section.header.val = {
        [[┌──────────────────────────────────────────────────────────────┐]],
        [[│                    P R O P E R T Y   O F                     │]],
        [[│ ASSET  74-2219-B                               REG  NCC-4180 │]],
        [[│                                                              │]],
        [[│                 W E Y L A N D - Y U T A N I                  │]],
        [[├──────────────────────────────────────────────────────────────┤]],
        [[│                           ________                           │]],
        [[│                          /        \                          │]],
        [[│                         /    /\    \                         │]],
        [[│                        /    /  \    \                        │]],
        [[│                        \   /____\   /                        │]],
        [[│                         \   ████   /                         │]],
        [[│                          \________/                          │]],
        [[├──────────────────────────────────────────────────────────────┤]],
        [[│             D E E P   S P A C E   S Y S T E M S              │]],
        [[│ ISSUE 03 / REV C                                CLASS M HULL │]],
        [[│                  D O   N O T   R E M O V E                   │]],
        [[└──────────────────────────────────────────────────────────────┘]],
      }

      -- One highlight range per header line. Ranges are {group, start, stop}
      -- with stop = -1 meaning end-of-line (alpha passes it straight to
      -- nvim_buf_add_highlight), which avoids hand-counting byte offsets —
      -- every box character here is 3 bytes wide, so column maths would be a
      -- trap. AlphaHeaderBar is reversed (dark on green) to read as the
      -- placard's two solid banner strips.
      local G, BAR, NAME = "AlphaHeader", "AlphaHeaderBar", "AlphaHeaderName"
      local DIM, AMBER = "AlphaHeaderDim", "AlphaHeaderAmber"
      local line_groups = {
        G,
        BAR,
        DIM,
        G,
        NAME,
        G,
        G,
        G,
        G,
        G,
        G,
        G,
        G,
        G,
        AMBER,
        DIM,
        BAR,
        G,
      }
      local hl = {}
      for i, group in ipairs(line_groups) do
        hl[i] = { { group, 0, -1 } }
      end
      dashboard.section.header.opts.hl = hl

      -- stylua: ignore
      dashboard.section.buttons.val = {
        dashboard.button("f", "  FIND FILE",       LazyVim.pick()),
        dashboard.button("n", "  NEW FILE",        [[<cmd> ene <BAR> startinsert <cr>]]),
        dashboard.button("r", "  RECENT FILES",    LazyVim.pick("oldfiles")),
        dashboard.button("g", "  FIND TEXT",       LazyVim.pick("live_grep")),
        dashboard.button("c", "  CONFIG",          LazyVim.pick.config_files()),
        dashboard.button("s", "  RESTORE SESSION", [[<cmd> lua require("persistence").load() <cr>]]),
        dashboard.button("x", "  LAZY EXTRAS",     "<cmd> LazyExtras <cr>"),
        dashboard.button("l", "󰒲  LAZY",            "<cmd> Lazy <cr>"),
        dashboard.button("q", "  QUIT",            "<cmd> qa <cr>"),
      }
      for _, button in ipairs(dashboard.section.buttons.val) do
        button.opts.hl = "AlphaButtons"
        button.opts.hl_shortcut = "AlphaShortcut"
      end

      dashboard.section.footer.opts.hl = "AlphaFooter"
      dashboard.opts.layout[1].val = 2
      return dashboard
    end,
    config = function(_, dashboard)
      -- close Lazy and re-open when the dashboard is ready
      if vim.o.filetype == "lazy" then
        vim.cmd.close()
        vim.api.nvim_create_autocmd("User", {
          once = true,
          pattern = "AlphaReady",
          callback = function()
            require("lazy").show()
          end,
        })
      end

      require("alpha").setup(dashboard.opts)

      vim.api.nvim_create_autocmd("User", {
        once = true,
        pattern = "LazyVimStarted",
        callback = function()
          local stats = require("lazy").stats()
          local ms = (math.floor(stats.startuptime * 100 + 0.5) / 100)
          -- Subsystem readout: loaded/total and boot time, the plates' way of
          -- saying "45 ONLINE".
          dashboard.section.footer.val =
            string.format("SUBSYSTEMS %d/%d ONLINE   ·   BOOT %sms", stats.loaded, stats.count, ms)
          pcall(vim.cmd.AlphaRedraw)
        end,
      })
    end,
  },
}
