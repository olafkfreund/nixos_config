{ config
, lib
, pkgs
, ...
}:
# Google Antigravity CLI (agy) — replaces Gemini CLI as of 2026-05-20
# per Google's official transition (Gemini CLI EOL 2026-06-18).
#
# The `agy` binary reads the SAME env vars as the old `gemini` CLI
# (GEMINI_API_KEY, GEMINI_MODEL) per the upstream migration docs at
# https://www.antigravity.google/docs/gcli-migration — so users keep
# the agenix `api-gemini` secret unchanged.
#
# Hard-cut from `gemini` to `agy`: no transitional shell alias retained,
# per the explicit policy choice in the migrating PR.
let
  inherit (lib) mkIf mkDefault;
  cfg = config.features.ai;
  package = pkgs.customPkgs.antigravity-cli;
  environmentVariables = { };
  enableShellIntegration = true;

  # agy's --sandbox hides /run, where nix-ld's default NIX_LD points, so every
  # non-Nix binary (uv python, ruff) aborts in nix-ld there. Use the store paths.
  agy =
    if config.programs.nix-ld.enable then
      pkgs.symlinkJoin
        {
          name = "agy-nix-ld";
          paths = [ package ];
          nativeBuildInputs = [ pkgs.makeWrapper ];
          postBuild = ''
            wrapProgram $out/bin/agy \
              --set NIX_LD ${pkgs.stdenv.cc.bintools.dynamicLinker} \
              --set NIX_LD_LIBRARY_PATH ${lib.makeLibraryPath config.programs.nix-ld.libraries}
          '';
        }
    else
      package;
in
{
  config = mkIf (cfg.enable && cfg.antigravity-cli) {
    environment = {
      systemPackages = [ agy ];
      variables = environmentVariables;

      # Shell integration: `agy` is the canonical name. `ai` keeps its
      # default-priority alias so user muscle memory survives.
      shellAliases = mkIf enableShellIntegration {
        ai = mkDefault "agy";
      };

      etc."applications/antigravity-cli.desktop" = mkIf enableShellIntegration {
        text = ''
          [Desktop Entry]
          Name=Antigravity CLI
          Comment=Google Antigravity AI Command Line Interface (agy)
          Exec=env -u OPENAI_API_KEY -u OPENAI_API_KEY_FILE -u GEMINI_API_KEY -u GEMINI_API_KEY_FILE -u GOOGLE_API_KEY -u ANTHROPIC_API_KEY -u ANTHROPIC_API_KEY_FILE ${agy}/bin/agy --dangerously-skip-permissions
          Icon=terminal
          Type=Application
          Terminal=true
          Categories=Development;Utility;ConsoleOnly;
          Keywords=AI;Antigravity;Gemini;CLI;Google;agy;
        '';
      };
    };
  };
}
