-- Local Ollama chat / inline / agentic edits via CodeCompanion.
-- Keymaps live under <leader>o ("ollama") so <leader>a stays 100% Claude Code.
-- Model: qwen2.5-coder:14b (already pulled). OLLAMA_ENDPOINT env overrides host.
-- Mental model: <leader>o = small/private/offline edits + completion on your own
-- GPU; <leader>a (Claude Code) = big multi-file agentic refactors.
return {
  {
    "olimorris/codecompanion.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-treesitter/nvim-treesitter",
    },
    cmd = {
      "CodeCompanion",
      "CodeCompanionChat",
      "CodeCompanionActions",
      "CodeCompanionCmd",
    },
    keys = {
      { "<leader>o", "", desc = "+ollama (codecompanion)", mode = { "n", "v" } },
      { "<leader>oo", "<cmd>CodeCompanionActions<cr>", mode = { "n", "v" }, desc = "CodeCompanion actions" },
      { "<leader>oc", "<cmd>CodeCompanionChat Toggle<cr>", mode = { "n", "v" }, desc = "Toggle Ollama chat" },
      { "<leader>oi", ":CodeCompanion ", mode = { "n", "v" }, desc = "Inline Ollama prompt" },
      { "<leader>oa", "<cmd>CodeCompanionChat Add<cr>", mode = "v", desc = "Add selection to chat" },
    },
    opts = {
      adapters = {
        http = {
          ollama = function()
            return require("codecompanion.adapters").extend("ollama", {
              env = {
                url = vim.env.OLLAMA_ENDPOINT or "http://localhost:11434",
              },
              schema = {
                model = { default = "qwen2.5-coder:14b" },
                num_ctx = { default = 16384 },
              },
            })
          end,
        },
      },
      strategies = {
        chat = { adapter = "ollama" },
        inline = { adapter = "ollama" },
        cmd = { adapter = "ollama" },
      },
    },
  },
}
