{pkgs, ...}: {
  services.xserver.displayManager.startx.enable = true;
  services.xserver.windowManager.dwm.enable = true;
  services.picom.enable = true;
  nixpkgs.overlays = [
    (final: prev: {
      dwm = prev.dwm.overrideAttrs (old: {
        src = ./chadwm;
        buildInputs = old.buildInputs ++ [pkgs.imlib2];
      });
    })
  ];
  environment.systemPackages = with pkgs; [
    imlib2Full
    xorg.xsetroot
    slstatus
    gnumake
    xorg.libX11.dev
    xorg.libXft
    xorg.libXinerama
    xorg.xinit
    xorg.xrdb
    xorg.xset
    xorg.xbacklight
    xorg.xrandr
    sx
    light
    libgcc
    dash
    autorandr
  ];
}
