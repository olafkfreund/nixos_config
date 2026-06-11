-- Local Ollama inline completion (Copilot-but-local) via minuet-ai.
-- FIM model: qwen2.5-coder:7b on the local Ollama (OLLAMA_ENDPOINT env overrides
-- the host, e.g. http://p620:11434 from a machine without a local daemon).
-- Surfaces as a blink.cmp source (see blink.lua) so AI suggestions sit in the
-- normal completion menu alongside LSP — no duplicate ghost-text. Throttled to
-- keep the local GPU sane.
return {
  {
    "milanglacier/minuet-ai.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    event = "InsertEnter",
    config = function()
      require("minuet").setup({
        provider = "openai_fim_compatible",
        n_completions = 1, -- one suggestion → lighter on a local model
        context_window = 1024,
        request_timeout = 4,
        throttle = 1500, -- ms between requests
        debounce = 600,
        provider_options = {
          openai_fim_compatible = {
            api_key = "TERM", -- dummy; Ollama needs no key
            name = "Ollama",
            end_point = (vim.env.OLLAMA_ENDPOINT or "http://localhost:11434") .. "/v1/completions",
            model = "qwen2.5-coder:7b",
            stream = true,
            optional = {
              max_tokens = 256,
              top_p = 0.9,
            },
          },
        },
      })
    end,
  },
}
