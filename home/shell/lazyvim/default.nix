{ pkgs, lib, config, ... }:
let
  inherit (config.lib.stylix) colors;
in
{
  home.file.".config/nvim" = {
    source = ./lazyvim;
    recursive = true;
  };

  # Alien HUD colorscheme. Generated here rather than living in ./lazyvim so
  # the palette comes from the Stylix base16 scheme
  # (assets/themes/alien-hud.yaml) instead of being a fourth hand-copy of the
  # same hex values — same approach as home/shell/splashboard/default.nix.
  #
  # base16-nvim's `setup()` takes a raw base00..base0F table, which is exactly
  # what Stylix exposes, so no colorscheme file has to be authored. LazyVim's
  # `colorscheme` opt accepts a function (lazyvim/config/init.lua:252), and
  # that is the only way to load a palette that isn't a named colorscheme.
  home.file.".config/nvim/lua/plugins/colorscheme.lua".text = ''
    return {
      { "RRethy/base16-nvim", lazy = false, priority = 1000 },

      {
        "LazyVim/LazyVim",
        opts = {
          colorscheme = function()
            require("base16-colorscheme").setup({
              base00 = "#${colors.base00}",
              base01 = "#${colors.base01}",
              base02 = "#${colors.base02}",
              base03 = "#${colors.base03}",
              base04 = "#${colors.base04}",
              base05 = "#${colors.base05}",
              base06 = "#${colors.base06}",
              base07 = "#${colors.base07}",
              base08 = "#${colors.base08}",
              base09 = "#${colors.base09}",
              base0A = "#${colors.base0A}",
              base0B = "#${colors.base0B}",
              base0C = "#${colors.base0C}",
              base0D = "#${colors.base0D}",
              base0E = "#${colors.base0E}",
              base0F = "#${colors.base0F}",
            })

            -- base16-nvim maps the palette onto standard groups but treats
            -- every window as a flat surface. These are the plate-specific
            -- reads: hairline seams, phosphor-green box outlines and titles,
            -- and floats that sit on the background rather than a lighter
            -- fill, so a float reads as a HUD panel cut into the plate.
            local hud = {
              WinSeparator = { fg = "#${colors.base03}" },
              FloatBorder = { fg = "#${colors.base0B}", bg = "#${colors.base00}" },
              NormalFloat = { fg = "#${colors.base05}", bg = "#${colors.base00}" },
              FloatTitle = { fg = "#${colors.base0B}", bg = "#${colors.base00}", bold = true },
              FloatFooter = { fg = "#${colors.base04}", bg = "#${colors.base00}" },
              Title = { fg = "#${colors.base0B}", bold = true },
              CursorLine = { bg = "#${colors.base01}" },
              CursorLineNr = { fg = "#${colors.base0B}", bold = true },
              LineNr = { fg = "#${colors.base03}" },
              Visual = { bg = "#${colors.base02}" },
              MatchParen = { fg = "#${colors.base0A}", bold = true },
              Search = { fg = "#${colors.base00}", bg = "#${colors.base0A}" },
              IncSearch = { fg = "#${colors.base00}", bg = "#${colors.base09}" },
              WinBar = { fg = "#${colors.base0B}", bg = "#${colors.base00}", bold = true },
              WinBarNC = { fg = "#${colors.base04}", bg = "#${colors.base00}" },
              -- Indent guides / scope (snacks.indent).
              SnacksIndent = { fg = "#${colors.base01}" },
              SnacksIndentScope = { fg = "#${colors.base0B}" },
              -- Start screen (lua/plugins/alpha-nvim.lua) — the asset placard.
              AlphaHeader = { fg = "#${colors.base0B}" },
              AlphaHeaderBar = { fg = "#${colors.base00}", bg = "#${colors.base0B}", bold = true },
              AlphaHeaderName = { fg = "#${colors.base05}", bold = true },
              AlphaHeaderAmber = { fg = "#${colors.base09}", bold = true },
              AlphaHeaderDim = { fg = "#${colors.base04}" },
              AlphaButtons = { fg = "#${colors.base05}" },
              AlphaShortcut = { fg = "#${colors.base0A}", bold = true },
              AlphaFooter = { fg = "#${colors.base04}" },
            }
            for group, spec in pairs(hud) do
              vim.api.nvim_set_hl(0, group, spec)
            end
          end,
        },
      },
    }
  '';

  # Expose the Nix-built blink.cmp (with prebuilt Rust fuzzy matcher) at a
  # stable path so lazy.nvim can load it via `dir = ...` and skip the broken
  # release-binary download.
  #
  # It must be a WRITABLE copy, not a home.file symlink: lazy.nvim always runs
  # `:helptags doc/` on sync, and a read-only nix-store path makes that fail
  # with E152 ("Cannot open .../doc/tags for writing"). home.file (even with
  # recursive=true) keeps the tree read-only, so copy it out and chmod +w.
  # Idempotent — only re-copies when the source store path changes.
  home.activation.blinkCmpWritable = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    dest="$HOME/.local/share/nix-vim-plugins/blink.cmp"
    src="${pkgs.vimPlugins.blink-cmp}"
    if [ "$(cat "$dest/.nix-src" 2>/dev/null)" != "$src" ]; then
      $DRY_RUN_CMD rm -rf "$dest"
      $DRY_RUN_CMD mkdir -p "$dest"
      $DRY_RUN_CMD cp -rL "$src/." "$dest/"
      $DRY_RUN_CMD chmod -R u+w "$dest"
      $DRY_RUN_CMD echo "$src" > "$dest/.nix-src"
    fi
  '';
}
