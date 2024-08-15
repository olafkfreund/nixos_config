{ pkgs, ... }: {
  home.packages = with pkgs; [
    python3
    python312Packages.pip
    python312Packages.pynvim
    python312Packages.pynvim-pp
    python312Packages.dbus-python
    python312Packages.ninja
    python312Packages.material-color-utilities
    python312Packages.numpy
    python312Packages.pyyaml
    python312Packages.google-generativeai
    python312Packages.google
    python312Packages.google-auth
    python312Packages.syncedlyrics
    python312Packages.pygobject3
    python312Packages.pycairo
    python312Packages.pillow
    python312Packages.requests
  ];
}
