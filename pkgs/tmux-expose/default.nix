{ lib
, rustPlatform
, fetchFromGitHub
,
}:
# tmux-expose — Mission Control-style tmux session switcher with live
# terminal previews. Upstream is a Rust binary + a thin tmux.expose.tmux
# wrapper that sets up the keybinding. We package the binary and inline
# the keybinding in home/shell/tmux/default.nix.
#
# Upstream: https://github.com/cesarferreira/tmux.expose
rustPlatform.buildRustPackage {
  pname = "tmux-expose";
  version = "0.4.1";

  src = fetchFromGitHub {
    owner = "cesarferreira";
    repo = "tmux.expose";
    rev = "837e22702b6938d26f15d956f315c0dff0463902"; # v0.4.1 commit (no release tag yet)
    hash = "sha256-jNBjaFnvueB6Q+5AsC9BWRghdTIsZv93JqxgPM9CEIM=";
  };

  cargoHash = "sha256-cRl/5/nUNDayiygCpguv0A5ubw28GfX7MScbgTgjcoI=";

  # Pure Rust (anyhow, clap, crossterm, ratatui) — no native deps.

  meta = with lib; {
    description = "Mission Control-style tmux session switcher with live terminal previews";
    homepage = "https://github.com/cesarferreira/tmux.expose";
    license = licenses.mit;
    platforms = platforms.linux;
    mainProgram = "tmux-expose";
  };
}
