{ lib
, rustPlatform
, fetchFromGitHub
, installShellFiles
}:
# rmux — Universal Rust terminal multiplexer with a tmux-compatible CLI,
# detachable daemon, typed Rust SDK, and Ratatui widget integration.
# Targeted at "agentic" workflows where you want to drive a TUI app from code
# (e.g. orchestrating Claude Code sessions with `pane.wait_for_text(...)`
# instead of `tmux send-keys + sleep + capture-pane`).
#
# Upstream: https://github.com/Helvesec/rmux (released 2026-05-23, very new)
# Not in nixpkgs (as of 2026-05-24).
#
# Pure crates.io deps (no git+ entries in Cargo.lock) — sidesteps the
# nixpkgs-unstable nix-prefetch-git regression that bites the COSMIC
# packages.
rustPlatform.buildRustPackage rec {
  pname = "rmux";
  version = "0.3.0";

  src = fetchFromGitHub {
    owner = "Helvesec";
    repo = "rmux";
    rev = "v${version}";
    hash = "sha256-0bdbuF8vSD9O7YR+pOrhoxltIbzme99YFzgVTh/N9Rs=";
  };

  cargoHash = "sha256-aOsvNFUGJPfWVbTlaTYL2tB8M2x/dLuXYPUXvkWRqKI=";

  # Disable check phase: rmux's integration test suite spawns child shells
  # (`/bin/sh`) for every pane it creates, which doesn't exist in the Nix
  # build sandbox. Whitelisting individual tests becomes whack-a-mole
  # because most of the suite covers session/pane lifecycle. Upstream CI
  # tests against a real environment; we just need a building binary here.
  doCheck = false;

  nativeBuildInputs = [ installShellFiles ];

  # Install the upstream-shipped manpage so `man rmux` works.
  postInstall = ''
    installManPage rmux.1
  '';

  meta = with lib; {
    description = "Universal Rust terminal multiplexer with typed SDK for driving CLI/TUI apps";
    homepage = "https://rmux.io";
    license = with licenses; [ mit asl20 ]; # dual licensed
    platforms = platforms.unix;
    mainProgram = "rmux";
  };
}
