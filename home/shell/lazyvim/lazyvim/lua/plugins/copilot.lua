return {
  {
    "zbirenbaum/copilot.lua",
    cmd = "Copilot",
    build = ":Copilot auth",
    event = "InsertEnter", -- Recommended lazy loading strategy
    opts = {
      suggestion = {
        enabled = true,
        auto_trigger = true,
        debounce = 75,
        keymap = {
          accept = "<C-l>",
          accept_word = false,
          accept_line = false,
          next = "<M-]>",
          prev = "<M-[>",
          dismiss = "<C-]>",
        },
      },
      panel = {
        enabled = true,
        auto_refresh = true,
        keymap = {
          jump_prev = "[[",
          jump_next = "]]",
          accept = "<CR>",
          refresh = "gr",
          open = "<M-CR>",
        },
        layout = {
          position = "bottom", -- | top | left | right
          ratio = 0.4,
        },
      },
      filetypes = {
        markdown = true,
        help = true,
        nix = true,
        lua = true,
        -- Add more filetypes that would benefit from Copilot
        yaml = true,
        json = true,
        typescript = true,
        javascript = true,
        python = true,
        rust = true,
        go = true,
      },
      -- Add copilot-cmp integration
      cmp = {
        enabled = true,
        method = "getCompletionsCycling",
      },
      -- Improve diagnostics and logging
      server_opts_overrides = {
        trace = "verbose", -- Set to "off" in production for better performance
        settings = {
          advanced = {
            listCount = 10,     -- Number of completions to fetch
            inlineSuggestCount = 3, -- Number of inline suggestions
          }
        }
      },
      -- Ensure compatibility with Node.js 20+ (required as of May 2025)
      -- Uncomment and adjust if you have issues with Node.js version
      -- copilot_node_command = vim.fn.expand("$HOME") .. "/.nvm/versions/node/v20.10.0/bin/node",
    },
    -- Recommended dependencies
    dependencies = {
      -- Add copilot-cmp for completion integration
      {
        "zbirenbaum/copilot-cmp",
        dependencies = { "hrsh7th/nvim-cmp" },
        config = function()
          require("copilot_cmp").setup()
        end,
      },
    },
  },
  -- Optional status indicator in your statusline
  {
    "AndreM222/copilot-lualine",
    dependencies = { "nvim-lualine/lualine.nvim" },
    lazy = true,
    event = "InsertEnter",
  },
}
