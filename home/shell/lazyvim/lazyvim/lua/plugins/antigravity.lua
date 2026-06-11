-- Antigravity (agy) in Neovim.
-- There is no mature nvim plugin for Antigravity (it's a standalone VS Code
-- fork). The robust path mirrors the Claude Code workflow: launch the `agy`
-- CLI in a snacks terminal split on <leader>ag. The shared repo-root AGENTS.md
-- already gives agy the same project context Claude and Ollama get.
return {
  {
    "folke/snacks.nvim",
    keys = {
      {
        "<leader>ag",
        function()
          require("snacks").terminal("agy", {
            win = { position = "right", width = 0.4 },
          })
        end,
        desc = "Antigravity (agy) terminal",
      },
    },
  },
}
