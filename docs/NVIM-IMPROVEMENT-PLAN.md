<!-- markdownlint-disable MD013 -->

# Neovim Improvement Plan — Claude Code + Antigravity + local Ollama

> Created: 2026-06-11
> Scope: review + plan only (nothing changed yet). Goal: the ideal LazyVim coding
> setup for *your* AI stack — Claude Code, Antigravity, local Ollama — and nothing else.

## Status snapshot

Your nvim is **LazyVim**, config at `home/shell/lazyvim/` (delivered via `home.file`,
lazy.nvim manages plugins). It's already in good shape on the Claude side; the
**local-Ollama layer is the big missing piece**.

| Area | Current | Verdict |
|---|---|---|
| **Claude Code ↔ nvim** | `coder/claudecode.nvim` + official `extras.ai.claudecode`; snacks terminal, right 35% split, `<leader>a*` keymaps | 🟢 **best-in-class, already done** |
| Completion engine | blink.cmp, **Nix-built** (prebuilt Rust fuzzy matcher) | 🟢 ideal |
| Nix LSP | `nixd` via lspconfig (Nix-provided, no Mason) | 🟢 correct |
| **Local Ollama (inline completion)** | none | 🔴 **missing** — your "Copilot but local" |
| **Local Ollama (chat / agentic edits)** | none | 🔴 **missing** |
| Other-language LSP/format | no LazyVim `lang.*` extras enabled (rust/python/go/ts) | 🟡 relies on defaults |
| File explorer for @-mentions | (not confirmed oil) | 🟡 `oil.nvim` helps claudecode @-mentions |
| **Antigravity ↔ nvim** | `agy` only via tmux palette | ⚪ no real nvim plugin (honest, below) |

**Ollama models you already have** (localhost:11434): `qwen2.5-coder:14b` ✅ (chat-ready), plus qwen3/gemma. **Missing for fast inline FIM:** `qwen2.5-coder:7b`.

**Headline:** Claude Code is already wired the right way. The whole opportunity is **adding the local-Ollama coding layer** (inline FIM completion + a local chat/agentic editor), plus tightening language tooling. No avante, no Copilot — exactly your "only Claude/Antigravity/Ollama" constraint.

---

## The recommended stack (opinionated)

| Layer | Pick | Role |
|---|---|---|
| Claude Code | `coder/claudecode.nvim` *(have it)* | Big agentic jobs, diffs, selection/diagnostics → Claude |
| **Inline completion** | `milanglacier/minuet-ai.nvim` → Ollama FIM | As-you-type ghost text from a local model (blink source) |
| **Chat / agentic (local)** | `olimorris/codecompanion.nvim` → Ollama adapter | `@buffers`/`@lsp` chat, inline rewrites — private/offline. Also an **ACP Claude-Code front-end** |
| Antigravity | terminal/tmux `agy` *(have it)* | No load-bearing nvim plugin yet — see below |
| Fundamentals | LazyVim `lang.*` extras + Nix LSPs | Solid IDE base under the AI |

**Deliberately excluded:** `avante.nvim` (overlaps Claude Code's diff-apply *and* has a Rust build that's the #1 NixOS pain), Copilot/Supermaven (cloud, not your stack), `gen.nvim`/`ollama.nvim` (superseded by codecompanion).

---

## Plan

### Phase 1 — Local Ollama coding layer (the gap) `M`

**Goal: a private, offline "Copilot + Cursor-lite" running on your own GPU.**

1. **Inline completion — `minuet-ai.nvim`** as a blink.cmp source, `openai_fim_compatible` provider → `http://localhost:11434/v1/completions`, model `qwen2.5-coder:7b`, `max_tokens≈256`, streaming on. Ghost-text completion as you type, fully local.
   - Add `"minuet"` to `blink.lua` `sources.default`.
2. **Chat / agentic — `codecompanion.nvim`** with the Ollama adapter (`qwen2.5-coder:14b`, which you already have). Gives `:CodeCompanion` inline rewrites, a chat buffer with `@buffers`/`@lsp` context, and slash-commands. Keymaps under a non-conflicting prefix (e.g. `<leader>o` for "ollama", keeping `<leader>a` = Claude).
   - **Bonus:** codecompanion also has an **ACP `claude_code` adapter** — optional, lets you drive Claude Code from inside a chat buffer too (one UI for both). Optional; you already have claudecode.nvim for that.
3. **Pull the FIM model on p620:** `ollama pull qwen2.5-coder:7b` (fast FIM). Keep `:14b` for chat; optionally try `:32b` for heavier chat if ROCm VRAM allows.

**Routing rule (the mental model):** small/private/offline edits + autocomplete → **Ollama**; big multi-file agentic refactors → **Claude Code** (a local 7–14B won't match it). Two keymap families: `<leader>a` Claude, `<leader>o` Ollama.

**Verify:** ghost-text appears from Ollama; `:CodeCompanion` rewrites a selection; Claude `<leader>a` flow unchanged; nvim startup not regressed.

### Phase 2 — Coding fundamentals (tighten, stay lean) `S`

1. **Enable LazyVim `lang.*` extras** for your stack: `lang.rust`, `lang.python`, `lang.go`, `lang.typescript` (you already have nix). These wire LSP + formatter + treesitter per language.
2. **Keep LSP/formatters Nix-provided** (the Mason-on-NixOS trap): ensure `rust-analyzer`, `pyright`/`ruff`, `gopls`, `typescript-language-server`, `lua-language-server`, plus `stylua`/`alejandra`/`prettierd` come from Nix, and Mason auto-install stays off. (nixd already does this for Nix.)
3. **`oil.nvim`** as the editable file explorer — it's the surface `claudecode.nvim` (and antigravity-cli.nvim) hook for `@`-mentioning files/dirs into the AI.

### Phase 3 — Antigravity in nvim (honest, low priority) `XS`

There is **no official Google nvim plugin** (Antigravity is a standalone VS Code/Windsurf fork). Options, least-risk first:

1. **Keep `agy` in a terminal/tmux split** (you already launch it from the M-a palette) — robust, no surprises. **Recommended.**
2. *Optionally* trial the community **`McEazy2700/antigravity-cli.nvim`** (MCP-over-HTTP, native vimdiff) — real but single-maintainer/experimental; don't make it load-bearing.
3. The **shared `AGENTS.md`** you already shipped means Antigravity, Claude, and Ollama agents share project context regardless.

---

## NixOS strategy (keep it painless)

- **Let lazy.nvim keep managing the plugins** (mutable, fast iteration). `minuet-ai`, `codecompanion`, `claudecode` are **pure Lua, no build step** → just add lazy specs. Provide the *binaries* via Nix (you already have `ollama`/`ollama-rocm`, `claude`, `agy`, `nixd`, blink's prebuilt matcher).
- **Avoid avante** precisely because its Rust build is the one thing that fights Nix.
- No new flake inputs needed for Phase 1.

## Open questions for you

1. **Inline completion model:** pull `qwen2.5-coder:7b` (fast, recommended) or reuse `:14b` (slower ghost-text, one fewer model)?
2. **codecompanion keymaps:** OK to claim `<leader>o` (ollama) so `<leader>a` stays 100% Claude?
3. Want the **ACP claude_code adapter** in codecompanion too (one chat UI for Claude + Ollama), or keep them separate (claudecode.nvim for Claude, codecompanion for Ollama)?

## Sources

`coder/claudecode.nvim` (+ LazyVim ai.claudecode extra), `milanglacier/minuet-ai.nvim` (Ollama FIM recipe), `olimorris/codecompanion.nvim` (Ollama + ACP adapters), avante-vs-codecompanion 2026 writeup, qwen2.5-coder/codestral/deepseek-coder model rankings, `McEazy2700/antigravity-cli.nvim` (experimental). Full list in the research thread.
