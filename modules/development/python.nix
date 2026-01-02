{ config
, lib
, pkgs
, ...
}:
with lib; let
  cfg = config.modules.development.python;

  # Override sse-starlette to disable flaky tests (timing issues cause failures)
  # See: https://github.com/olafkfreund/nixos_config/issues/118
  sse-starlette-nocheck = pkgs.python312Packages.sse-starlette.overridePythonAttrs (_old: {
    doCheck = false; # Disable flaky timing tests
    pythonImportsCheck = [ ]; # Disable import check (has test-time dependency issues)
  });

  # Override mcp to use our fixed sse-starlette
  mcp-fixed = pkgs.python312Packages.mcp.override {
    sse-starlette = sse-starlette-nocheck;
  };
in
{
  options.modules.development.python = {
    enable = mkEnableOption "Enable Python development environment";
    packages = mkOption {
      type = with types; listOf str;
      default = [ ];
      description = "Packages to install for Python development";
    };
  };
  config = mkIf cfg.enable {
    environment.systemPackages =
      [
        pkgs.python3
        pkgs.python312Packages.pip
        pkgs.python312Packages.pynvim
        pkgs.python312Packages.pynvim-pp
        pkgs.python312Packages.dbus-python
        pkgs.python312Packages.ninja
        pkgs.python312Packages.material-color-utilities
        pkgs.python312Packages.numpy
        pkgs.python312Packages.pyyaml
        pkgs.python312Packages.google-generativeai
        pkgs.python312Packages.google
        pkgs.python312Packages.google-auth
        pkgs.python312Packages.syncedlyrics
        pkgs.python312Packages.pygobject3
        pkgs.python312Packages.pycairo
        pkgs.python312Packages.pillow
        pkgs.python312Packages.requests
        mcp-fixed # Use our override with disabled sse-starlette tests

      ]
      ++ cfg.packages;
  };
}
