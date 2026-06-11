<!-- markdownlint-disable MD013 -->

# Zsh Improvement Plan — from good to great

> Created: 2026-06-11
> Scope: review + plan only (nothing changed yet). Target: a faster, leaner,
> more workflow-tuned zsh, fully declarative in home-manager.

## Status snapshot

Your zsh is **feature-rich but heavy**. Measured + audited state:

| Signal | Current | Target | Verdict |
|---|---|---|---|
| Interactive startup | **~660 ms** (warm) | 100–150 ms | 🔴 5–6× too slow |
| `home/shell/zsh.nix` | 692 lines, ~465-line monolithic `initContent` | modular, `mkOrder` | 🟠 hard to maintain |
| oh-my-zsh | **enabled, 11 plugins** (aws, azure, terraform, lxd, 1password…) + `theme=gruvbox` | removed | 🔴 prime bloat source |
| starship | own module **and** an OMZ plugin (+ OMZ theme) | one source | 🟠 redundant/conflicting |
| atuin | hand-init `eval "$(atuin init zsh)"` | `programs.atuin` | 🟠 suboptimal ordering/flags |
| history | hand `export HISTSIZE/SAVEHIST` in initContent | `programs.zsh.history` | 🟠 should be declarative |
| fzf-tab | present + tuned | keep, minor tune | 🟢 good |
| syntax-highlighting / autosuggestion | built-in HM options | keep | 🟢 good |
| zoxide / fzf / eza / bat / direnv / yazi | dedicated modules | keep | 🟢 good |
| abbreviations | none | `zsh-abbr` | 🟡 missing high-value feature |
| history arrows | none | `historySubstringSearch` | 🟡 missing |

**What's genuinely good:** the modern-CLI stack is already here (zoxide, fzf, fzf-tab, eza, bat, direnv, yazi, starship, ripgrep), built-in syntax-highlighting + autosuggestions, and nice custom touches (the command-box prompt decoration, `nhs`/`nhsb` deploy helpers, `_aichat_zsh`). **The problem isn't missing features — it's bloat (OMZ), redundancy, and a monolithic file.**

**Headline:** removing oh-my-zsh + moving atuin/history to HM modules should cut startup from ~660 ms to ~120 ms (≈5× faster) with **zero feature loss**, because everything OMZ provides is already covered by HM modules or replaceable in a few lines.

---

## Must preserve (do not regress)

- The **command-box prompt decoration** (`draw_command_box`, `precmd/preexec_command_box`, `toggle_boxes`, separators).
- `nhs` / `nhsb` deploy helpers, `_aichat_zsh`, `gcheck`, `sane-ask`, `get_term_width`.
- starship prompt, gruvbox aesthetic, zoxide/fzf/eza/bat/direnv/yazi integrations.

---

## Plan

### Phase 0 — Performance: kill the bloat (biggest win) `M`

**Goal: ~660 ms → ~120 ms, no feature loss.**

1. **Remove oh-my-zsh.** Replace each plugin's actual value:
   - `git` → you only override `gl`; add the handful of git shortcuts you use as **`zsh-abbr`** (Phase 2). No OMZ needed.
   - `sudo` (Esc-Esc to prepend sudo) → 4-line `zle` widget in `initContent`.
   - `direnv` → already have `programs.direnv` module (drop the OMZ one).
   - `starship` → already a module (drop the OMZ plugin **and** `theme=gruvbox`; starship owns the prompt).
   - `history` → covered by `programs.zsh.history` + atuin.
   - `terraform`/`aws`/`azure`/`lxd` completions → **carapace** (Phase 1) or native completions; most you rarely tab-complete.
   - `1password`/`emoji-clock` → drop (negligible value).
2. **atuin → `programs.atuin`** (HM module) with `--disable-up-arrow`, `search_mode=fuzzy`, `style=compact`; remove the hand `eval`.
3. **De-dupe starship** (remove OMZ plugin + theme; keep the module).
4. **Cache compinit** via `completionInit` with the `-C` fresh-dump guard.
5. **Re-measure** with `zsh -i -c exit` ×5 and `zprof` to confirm the win and catch any new hotspot (defer with `zsh-defer` only if profiling demands).

**Verify:** startup ≤150 ms; prompt, atuin Ctrl-R, completions, command-boxes all still work.

### Phase 1 — History & completion done right `S`

1. **`programs.zsh.history`** (size/save 100000, `ignoreDups`, `ignoreSpace`, `expireDuplicatesFirst`, `extended`, `share`, path under `$XDG_DATA_HOME`) — delete the hand exports.
2. **`historySubstringSearch.enable`** → Up/Down = prefix search of local history (atuin stays on Ctrl-R). The two complement each other.
3. **Completion zstyles** (case-insensitive matcher, `menu no` so fzf-tab owns the menu, colors/descriptions) in an early `mkOrder 550` block.
4. **carapace** (optional, only if you live in cloud CLIs) for argument-aware completion of kubectl/gh/aws/etc., bridging the OMZ completions you're dropping.

### Phase 2 — Workflow ergonomics: make it work *for you* `S`

1. **`zsh-abbr`** (expand-on-space; keeps history readable) for muscle-memory across your stack:
   `g`→`git`, `gst`→`git status`, `gco`→`git checkout`, `drs`→`sudo nixos-rebuild switch --flake .`, `jd`→`just deploy`, `jq`/`jv`→`just …`, `n`→`nix`, `fu`→`nix flake update`.
2. **`dirHashes`**: `~nixos`, `~dl`, `~src` for instant jumps.
3. **`shellGlobalAliases`**: `G`=`| grep -i`, `L`=`| less`, `J`=`| jq`, `NE`=`2>/dev/null`.
4. **fzf pickers** (5-liners) tuned to your workflow:
   - `fj` — fzf over `just --summary`, run the chosen recipe (your justfile has 100+).
   - `fgb` — fzf git branch → checkout; `fkill` — fzf process → kill.
   - `fhost` — fzf p620/razer/p510 → ssh.
5. **Confirm `nix-direnv`** is on (`programs.direnv.nix-direnv.enable`) so `cd` into a flake auto-loads the dev shell — the single biggest multi-language-dev upgrade.

### Phase 3 — Maintainability: de-monolith `M`

Split the 692-line `zsh.nix` into focused files (imported from `home/shell/zsh/`):
`history.nix`, `completion.nix`, `keybindings.nix`, `aliases.nix`, `abbreviations.nix`, `functions.nix` (command-boxes + helpers), `plugins.nix`. Use `initContent` with `lib.mkOrder` (550 early / 1000 normal / 1400 late) instead of one giant string. Pure refactor — behaviour identical, far easier to evolve.

---

## Optional / situational (decide per taste)

- **Transient prompt** (collapse old prompts) — nice scrollback, but hand-wired zle in zsh (not free); only if you want it.
- **vi-mode**: builtin `defaultKeymap="viins"` is cheap; avoid `zsh-vi-mode` (it clobbers Ctrl-R → fights atuin).
- **`zsh-defer`**: only if Phase 0 profiling still shows a hotspot.
- Extra modern-unix tools you don't have yet: `delta` (git diffs — high value), `procs`, `dust`/`duf`, `sd`, `navi`.

---

## Risks / notes

- **OMZ removal migration:** the only real dependency is git aliases — you only customize `gl`, so risk is low; Phase 2 abbreviations replace what you use. Confirm you don't rely on obscure OMZ git aliases before removing.
- **Cloud-CLI completions** (terraform/aws/azure/lxd) disappear with OMZ — carapace (Phase 1) restores them if you actually tab-complete those.
- Do Phase 0 + re-measure before anything else — it's where the value is.

## Sources

home-manager `programs.zsh` module (option ground truth), Aloxaf/fzf-tab, atuin docs, olets/zsh-abbr, carapace, ibraheemdev/modern-unix, "P10k → Starship (2025)", zprof+zsh-defer profiling guide, fufexan/notusknot NixOS dotfiles.
