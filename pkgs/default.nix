{ pkgs, ... }: {
  # Define your custom packages here
  chrome-gruvbox-theme = pkgs.callPackage ./chrome-gruvbox-theme { };
  linux-command-mcp = pkgs.callPackage ./linux-command-mcp { };
  linkedin-mcp = pkgs.callPackage ./linkedin-mcp { };
  atlassian-mcp = pkgs.callPackage ./atlassian-mcp { };
  obsidian-mcp = pkgs.callPackage ./obsidian-mcp { nodejs = pkgs.nodejs_24; };
  obsidian-mcp-rest = pkgs.callPackage ./obsidian-mcp-rest { nodejs = pkgs.nodejs_24; };
  browser-mcp = pkgs.callPackage ./browser-mcp { nodejs = pkgs.nodejs_24; };
  whatsapp-mcp = pkgs.callPackage ./whatsapp-mcp { };
  plex-mcp-server = pkgs.callPackage ./plex-mcp-server { };
  arr-suite-mcp = pkgs.callPackage ./arr-suite-mcp { };
  audiobookbay-automated = pkgs.callPackage ./audiobookbay-automated { };
  m4b-tool = pkgs.callPackage ./m4b-tool { };
  audiobook-mcp = pkgs.callPackage ./audiobook-mcp { };
  mpris-album-art = pkgs.callPackage ./mpris-album-art { };
  weather-popup = pkgs.callPackage ./weather-popup { };
  # gemini-cli removed in #560 (replaced by pkgs.customPkgs.antigravity-cli)
  # Claude Desktop - native Linux build from k3d3/claude-desktop-linux-flake (see flake.nix overlay)
  claude-desktop = pkgs.claude-desktop-linux;
  neuwaita-icon-theme = pkgs.callPackage ./neuwaita-icon-theme { };
  kosli-cli = pkgs.callPackage ./kosli-cli { };

  # Override awscli2 to disable failing tests
  awscli2 = pkgs.awscli2.overrideAttrs (_oldAttrs: {
    doCheck = false; # Disable tests - 44 tests failing in wizard/test_app.py
  });

  # COSMIC applets
  cosmic-ext-applet-tailscale = pkgs.callPackage ./cosmic-applets/tailscale { };
  cosmic-ext-applet-next-meeting = pkgs.callPackage ./cosmic-applets/next-meeting { };

  aurynk = pkgs.callPackage ./aurynk { };

  # Newelle - AI Virtual Assistant (GTK4/Libadwaita)
  newelle = pkgs.callPackage ./newelle { };

  add-skill = pkgs.callPackage ./add-skill { };

  # Reddit TUI client
  reddix = pkgs.callPackage ./reddix { };

  # Claude Code native binary (alternative to npm-based package)
  claude-code-native = pkgs.callPackage ./claude-code-native { };

  # Antigravity IDE (2.0.1+) — Google's rebranded Antigravity Desktop.
  # Standalone derivation in pkgs/antigravity-ide/ because upstream
  # jacopone/antigravity-nix is still on 1.x and 2.0.x changed everything
  # (URL, layout, binary location, product name). Pinned to 2.0.1-4861014…
  antigravity-ide = pkgs.callPackage ./antigravity-ide/package.nix { };

  # Antigravity CLI (agy) — Gemini CLI's successor per Google's
  # 2026-05-20 transition. Single Go binary fetched from Google's manifest
  # URL. Replaces the npm-based gemini-cli package we used until #560.
  antigravity-cli = pkgs.callPackage ./antigravity-cli { };

  # Google Antigravity Python SDK — installs the platform-specific
  # PyPI wheel (binary runtime bundled inside; cannot build from source).
  # Wrapped as a Python env so `python` on PATH can `import google.antigravity`.
  google-antigravity-py = pkgs.python3.withPackages (ps: [
    (ps.callPackage ./google-antigravity-py { })
  ]);

  # FlyCrys — GTK4-native GUI for Claude Code (Rust). Not in nixpkgs yet;
  # custom buildRustPackage derivation. Wraps the local `claude` binary.
  flycrys = pkgs.callPackage ./flycrys { };

  # tmux-expose — Rust binary providing a Mission Control-style session
  # switcher inside tmux. Wired into home/shell/tmux/default.nix via a
  # display-popup bind-key (M-e by default).
  tmux-expose = pkgs.callPackage ./tmux-expose { };

  # tmux-palette — Raycast-style command palette for tmux. Bun + TypeScript.
  # Wired via two bind-keys in home/shell/tmux/default.nix: M-Space for the
  # general commands palette, M-a for the AI launcher (Claude Code +
  # Gemini CLI). The AI palette JSON is declared in the tmux module too.
  tmux-palette = pkgs.callPackage ./tmux-palette { };

  # rmux — Universal Rust terminal multiplexer with typed SDK. Runs
  # alongside tmux (separate daemon, different socket). Primarily added
  # for agent-orchestration scripting via rmux-sdk; for interactive
  # multiplexing tmux still owns the ergonomics here.
  rmux = pkgs.callPackage ./rmux { };

  # Note: gnome-ext-* packages are NOT registered here. They're exposed
  # at top-level pkgs.* via overlays/custom-packages.nix so that home
  # configs can reference them with `with pkgs;` (matching the rudra /
  # otp-keys / etc. pattern). Adding them here would expose them at
  # pkgs.customPkgs.gnome-ext-* which is a different namespace.
}
