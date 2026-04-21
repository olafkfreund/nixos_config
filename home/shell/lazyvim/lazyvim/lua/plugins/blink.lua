return {
  {
    "saghen/blink.cmp",
    lazy = false,
    dependencies = {
      "rafamadriz/friendly-snippets",
      "folke/lazydev.nvim",
    },
    -- Pin to 1.x releases so lazy.nvim picks up upstream's prebuilt Rust
    -- matcher binary (linux-x86_64.gz asset on each release). Using `false`
    -- (main HEAD) means no prebuilt is available, and since this is
    -- Nix-managed nvim — no cargo in the runtime — blink falls back to the
    -- Lua matcher and emits a loud warning on every startup.
    version = "1.*",
    opts = {
      keymap = {
        preset = "enter",
        ["<C-y>"] = { "select_and_accept" },
        ["<C-n>"] = { "select_next", "fallback" },
        ["<C-p>"] = { "select_prev", "fallback" },
        ["<C-Space>"] = { "show", "show_documentation", "hide_documentation" },
        ["<C-e>"] = { "hide" },
        ["<CR>"] = { "accept", "fallback" },
        ["<Tab>"] = { "select_next", "fallback" },
        ["<S-Tab>"] = { "select_prev", "fallback" },
      },
      appearance = {
        use_nvim_cmp_as_default = true,
        nerd_font_variant = "mono",
      },
      sources = {
        default = { "lsp", "path", "snippets", "buffer" },
      },
      completion = {
        accept = { auto_brackets = { enabled = true } },
        menu = {
          draw = {
            columns = {
              { "label", "label_description", gap = 1 },
              { "kind_icon", "kind" },
            },
          },
        },
        ghost_text = { enabled = true },
      },
    },
  },
}
