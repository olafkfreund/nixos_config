return {
  {
    "greggh/claude-code.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim", -- Required for git operations and utilities
    },
    event = "VeryLazy", -- Load after initial startup for better performance
    opts = {
      -- Window configuration for Claude Code terminal
      window = {
        split_ratio = 0.4, -- 40% of screen height for the Claude Code window
        position = "botright", -- Open in bottom-right position
        enter_insert = true, -- Automatically enter insert mode when opening
        width_ratio = 0.6, -- 60% of screen width for horizontal splits
      },

      -- Keymaps for Claude Code integration
      keymaps = {
        toggle = { "<C-,>", "Toggle Claude Code terminal" }, -- Toggle Claude Code terminal
      },

      -- Claude Code CLI configuration
      claude_code = {
        cmd = "claude-code", -- Command to run Claude Code CLI
        args = {}, -- Additional arguments for Claude Code CLI
        timeout = 30000, -- Timeout in milliseconds (30 seconds)
      },

      -- Git integration settings
      git = {
        auto_detect_root = true, -- Automatically detect git project root
        include_unstaged = false, -- Include unstaged changes in context
        include_untracked = false, -- Include untracked files in context
      },

      -- UI and behavior settings
      ui = {
        auto_scroll = true, -- Auto-scroll to bottom of output
        show_progress = true, -- Show progress indicators
        wrap_text = true, -- Wrap long lines in output
      },

      -- File types where Claude Code should be available
      filetypes = {
        "nix", "lua", "python", "javascript", "typescript",
        "rust", "go", "markdown", "yaml", "json", "sh", "bash"
      },
    },

    config = function(_, opts)
      require("claude-code").setup(opts)
    end,

    -- Define keymaps using LazyVim's keys spec
    keys = {
      { "<leader>cc", function() require("claude-code").toggle() end, desc = "Toggle Claude Code" },
      { "<leader>cq", function() require("claude-code").ask() end, desc = "Quick ask Claude" },
      { "<leader>ce", function() require("claude-code").explain_selection() end, desc = "Explain selected code", mode = "v" },
      { "<leader>cf", function() require("claude-code").fix_file() end, desc = "Fix current file" },
      { "<leader>cr", function() require("claude-code").review_changes() end, desc = "Review git changes" },
      
      -- Register the group using new which-key format
      { "<leader>c", group = "Claude Code" },
    },

    -- Commands for Claude Code integration
    cmd = {
      "ClaudeCode",
      "ClaudeCodeToggle",
      "ClaudeCodeAsk",
      "ClaudeCodeContinue",
      "ClaudeCodeNew",
    },
  },

  -- Optional: Enhance lualine with Claude Code status
  {
    "nvim-lualine/lualine.nvim",
    optional = true,
    opts = function(_, opts)
      -- Add Claude Code status to lualine if available
      if opts.sections and opts.sections.lualine_x then
        table.insert(opts.sections.lualine_x, {
          function()
            local claude_code = package.loaded["claude-code"]
            if claude_code and claude_code.is_active() then
              return "🤖 Claude"
            end
            return ""
          end,
          color = { fg = "#ff6b6b" },
        })
      end
    end,
  },
}
