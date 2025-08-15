{ pkgs, ... }: {
  nixpkgs.overlays = [
    (_self: super: {
      openrazer-daemon = super.openrazer-daemon.overrideAttrs (oldAttrs: {
        nativeBuildInputs = (oldAttrs.nativeBuildInputs or [ ]) ++ [ pkgs.gobject-introspection pkgs.wrapGAppsHook3 pkgs.python3Packages.wrapPython ];
      });

    })
  ];
}
