return {
  {
    "yetone/avante.nvim",
    event = "VeryLazy",
    lazy = false,
    version = false, -- set this if you want to always pull the latest change
    opts = {
      -- Enhanced options based on current documentation
      mappings = {
        ask = "<leader>aa",    -- Key to trigger the ask functionality
        edit = "<leader>ae",   -- Key to edit prompt/response
        refresh = "<leader>ar" -- Key to refresh the response
      },
      -- Using Copilot as the provider
      provider = "copilot",
    },
    -- if you want to build from source then do `make BUILD_FROM_SOURCE=true`
    build = "make",
    -- build = "powershell -ExecutionPolicy Bypass -File Build.ps1 -BuildFromSource false" -- for windows
    
    -- You can use keys to define custom mappings if desired
    keys = {
      { "<leader>aa", function() require("avante.api").ask() end, desc = "Avante: Ask AI" },
      { "<leader>ae", function() require("avante.api").edit() end, desc = "Avante: Edit" },
      { "<leader>ar", function() require("avante.api").refresh() end, desc = "Avante: Refresh" },
      -- Image paste shortcut that works both in normal buffers and Avante input
      { "<leader>ip", function()
          return vim.bo.filetype == "AvanteInput" and 
            require("avante.clipboard").paste_image() or 
            require("img-clip").paste_image()
        end, 
        desc = "Paste image (works in Avante too)"
      },
    },
    
    dependencies = {
      "stevearc/dressing.nvim",
      "nvim-lua/plenary.nvim",
      "MunifTanjim/nui.nvim",
      --- The below dependencies are optional,
      "nvim-tree/nvim-web-devicons", -- or echasnovski/mini.icons
      "zbirenbaum/copilot.lua", -- for providers='copilot'
      {
        -- support for image pasting
        "HakonHarnes/img-clip.nvim",
        event = "VeryLazy",
        opts = {
          -- recommended settings
          default = {
            embed_image_as_base64 = false,
            prompt_for_file_name = false,
            drag_and_drop = {
              insert_mode = true,
            },
            -- required for Windows users
            use_absolute_path = true,
          },
        },
      },
      {
        -- Make sure to set this up properly if you have lazy=true
        "MeanderingProgrammer/render-markdown.nvim",
        opts = {
          file_types = { "markdown", "Avante" },
        },
        ft = { "markdown", "Avante" },
      },
    },
  },
}
