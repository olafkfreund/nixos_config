return {
  {
    "coder/claudecode.nvim",
    dependencies = { "folke/snacks.nvim" },
    -- Load at startup so the /ide bridge exists before claude runs in another terminal.
    event = "VeryLazy",
    cmd = {
      "ClaudeCode",
      "ClaudeCodeFocus",
      "ClaudeCodeSend",
      "ClaudeCodeTreeAdd",
      "ClaudeCodeAdd",
      "ClaudeCodeOpen",
      "ClaudeCodeStatus",
    },
    opts = {
      terminal = {
        provider = "snacks",
        split_side = "right",
        split_width_percentage = 0.35,
      },
      auto_start = true,
    },
    keys = {
      { "<leader>ac", "<cmd>ClaudeCode<cr>", desc = "Toggle Claude Code" },
      { "<leader>af", "<cmd>ClaudeCodeFocus<cr>", desc = "Focus Claude Code" },
      { "<leader>as", "<cmd>ClaudeCodeSend<cr>", desc = "Send selection to Claude", mode = "v" },
      { "<leader>aa", "<cmd>ClaudeCodeAdd %<cr>", desc = "Add current file to Claude context" },
      { "<leader>aS", "<cmd>ClaudeCodeStatus<cr>", desc = "Claude Code status" },
    },
  },
}
