{ config, pkgs, lib, ... }:

{
  nixpkgs.overlays = [
  (self: super: {
    qtile-unwrapped = super.qtile-unwrapped.overrideAttrs(_: rec {
      postInstall = let
        qtileSession = ''
          [Desktop Entry]
          Name=Qtile Wayland
          Comment=Qtile on Wayland
          Exec=qtile start -b wayland
          Type=Application
        '';
        in
        ''
        mkdir -p $out/share/wayland-sessions
        echo "${qtileSession}" &gt; $out/share/wayland-sessions/qtile.desktop
        '';
      passthru.providedSessions = [ "qtile" ];
    });
  })
];

services.xserver.displayManager.sessionPackages = [ pkgs.qtile-unwrapped ];
}

