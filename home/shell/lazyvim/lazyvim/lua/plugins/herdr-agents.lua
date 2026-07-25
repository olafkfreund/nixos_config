-- herdr-agents.nvim — bridges claudecode.nvim into herdr.
--
-- claudecode.nvim (see claudecode.lua) opens Claude in a snacks terminal that
-- herdr knows nothing about: it is a child of this Neovim process, not a pane,
-- so it never appears in the agent panel and cannot be attached to or driven
-- from the herdr CLI. This plugin routes the terminal provider through herdr
-- instead, so an agent started from the editor becomes a real herdr pane.
--
-- Upstream is explicit that it "installs no mappings and reserves no leader
-- namespace", so it cannot collide with the existing <leader>a* claudecode
-- bindings — nothing here needs re-mapping.
--
-- codex.nvim is deliberately omitted: the codex CLI is not part of this
-- setup, and listing it would pull an unused plugin plus its snacks
-- dependency on every host.
--
-- Gated on HERDR_SOCKET_PATH (per upstream README) rather than HERDR_ENV: the
-- socket is what the bridge actually talks to, so this stays inert in a plain
-- terminal, over bare ssh, and on p510.
return {
  {
    "ctbaum/herdr-agents.nvim",
    cond = function()
      return vim.env.HERDR_SOCKET_PATH ~= nil and vim.env.HERDR_SOCKET_PATH ~= ""
    end,
    lazy = false,
    dependencies = {
      { "coder/claudecode.nvim", dependencies = { "folke/snacks.nvim" } },
    },
    opts = {},
  },
}
