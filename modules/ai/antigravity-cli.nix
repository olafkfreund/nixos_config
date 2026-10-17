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
  inherit (lib) mkOption mkIf mkEnableOption mkDefault types;
  cfg = config.modules.ai.antigravity-cli;

  # agy's --sandbox hides /run, where nix-ld's default NIX_LD points, so every
  # non-Nix binary (uv python, ruff) aborts in nix-ld there. Use the store paths.
  agy =
    if config.programs.nix-ld.enable then
      pkgs.symlinkJoin
        {
          name = "agy-nix-ld";
          paths = [ cfg.package ];
          nativeBuildInputs = [ pkgs.makeWrapper ];
          postBuild = ''
            wrapProgram $out/bin/agy \
              --set NIX_LD ${pkgs.stdenv.cc.bintools.dynamicLinker} \
              --set NIX_LD_LIBRARY_PATH ${lib.makeLibraryPath config.programs.nix-ld.libraries}
          '';
        }
    else
      cfg.package;
in
{
  options.modules.ai.antigravity-cli = {
    enable = mkEnableOption "Google Antigravity CLI (agy)";

    package = mkOption {
      type = types.package;
      default = pkgs.customPkgs.antigravity-cli;
      description = "The antigravity-cli package to use";
    };

    environmentVariables = mkOption {
      type = types.attrsOf types.str;
      default = { };
      description = "Environment variables to set for agy (still GEMINI_* per upstream migration docs)";
      example = {
        GEMINI_API_KEY = "your-api-key";
        GEMINI_MODEL = "gemini-2.5-pro";
      };
    };

    enableShellIntegration = mkOption {
      type = types.bool;
      default = true;
      description = "Enable shell integration (aliases + desktop entry)";
    };
  };

  config = mkIf cfg.enable {
    environment = {
      systemPackages = [ agy ];
      variables = cfg.environmentVariables;

      # Shell integration: `agy` is the canonical name. `ai` keeps its
      # default-priority alias so user muscle memory survives.
      shellAliases = mkIf cfg.enableShellIntegration {
        ai = mkDefault "agy";
      };

      etc."applications/antigravity-cli.desktop" = mkIf cfg.enableShellIntegration {
        text = ''
          [Desktop Entry]
          Name=Antigravity CLI
          Comment=Google Antigravity AI Command Line Interface (agy)
          Exec=${agy}/bin/agy
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
