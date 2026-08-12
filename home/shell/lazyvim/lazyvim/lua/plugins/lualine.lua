-- Statusline as the plates' bottom readout strip: uppercase mode in a
-- bracketed tab, hairline separators, no powerline wedges (the HUD is drawn
-- with box characters only, never filled arrows).
return {
  {
    "nvim-lualine/lualine.nvim",
    opts = function(_, opts)
      opts.options = vim.tbl_extend("force", opts.options or {}, {
        -- base16-nvim ships no lualine theme; "auto" derives the statusline
        -- colours from the active colorscheme's highlight groups.
        theme = "auto",
        section_separators = { left = "", right = "" },
        component_separators = { left = "│", right = "│" },
        globalstatus = true,
      })

      -- LazyVim builds sections a/b/c/x/y/z; only re-dress the ends so its
      -- diagnostics, git and root-dir components keep working.
      opts.sections = opts.sections or {}
      opts.sections.lualine_a = {
        {
          "mode",
          fmt = function(str)
            return "┤ " .. str:upper() .. " ├"
          end,
        },
      }
      opts.sections.lualine_z = {
        {
          "location",
          fmt = function(str)
            return "┤ " .. str .. " ├"
          end,
        },
      }
      return opts
    end,
  },
}
