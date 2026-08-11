-- Alien HUD motion and boxes.
--
-- This is the "how far can we go" layer: everything here is behaviour the
-- plates imply (things move, panels have titled boxes) that LazyVim ships
-- but leaves off. Colours are NOT set here — they come from the generated
-- lua/plugins/colorscheme.lua, which is the single palette source.
return {
  -- snacks.nvim is already a LazyVim dependency, so the animation modules
  -- cost no extra plugin. They are opt-in and off by default.
  {
    "folke/snacks.nvim",
    opts = {
      -- Smooth scrolling — the readouts sweep rather than jump.
      scroll = { enabled = true },

      -- Animated indent guides: the scope line grows out from the cursor,
      -- which is the closest thing nvim has to the plates' trace lines.
      indent = {
        enabled = true,
        animate = { enabled = true, duration = { step = 15, total = 250 } },
        scope = { enabled = true, char = "│", underline = false },
        chunk = { enabled = false },
      },

      -- Boxed toasts in the corner instead of a cmdline echo.
      notifier = { enabled = true, style = "fancy", top_down = false },

      -- Boxed vim.ui.input, matching the float chrome.
      input = { enabled = true },
    },
  },

  -- noice puts the cmdline in a titled box in the middle of the screen —
  -- the "SEQ 16" / "THERMAL BALANCE" label boxes from the plates. LazyVim
  -- already loads noice; this only restyles the views.
  {
    "folke/noice.nvim",
    opts = function(_, opts)
      opts.views = vim.tbl_deep_extend("force", opts.views or {}, {
        cmdline_popup = {
          border = { style = "single", text = { top = " CMD " } },
          position = { row = "40%", col = "50%" },
        },
        popupmenu = {
          border = { style = "single", text = { top = " COMPLETE " } },
        },
        confirm = {
          border = { style = "single", text = { top = " CONFIRM " } },
        },
        hover = { border = { style = "single" } },
      })
      return opts
    end,
  },

  -- which-key already renders a box; pin it to the same square border and
  -- keep it bottom-anchored like the HUD's status strip.
  {
    "folke/which-key.nvim",
    opts = {
      preset = "classic",
      win = { border = "single", title = true, title_pos = "left" },
    },
  },
}
