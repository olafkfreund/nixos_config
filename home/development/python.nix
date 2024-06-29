{ pkgs, ... }: {
  home.packages = with pkgs; [
    python3
    python311Packages.pip
    python311Packages.pynvim
    python311Packages.pynvim-pp
    python311Packages.dbus-python
    python311Packages.ninja
    python311Packages.material-color-utilities
    python311Packages.numpy
    python311Packages.pyyaml
    python311Packages.google-generativeai
    python311Packages.google
    python311Packages.google-auth
    python311Packages.syncedlyrics
    python311Packages.pygobject3
    python311Packages.pycairo
    python311Packages.pillow
    python311Packages.requests
    calcure
  ];
}
