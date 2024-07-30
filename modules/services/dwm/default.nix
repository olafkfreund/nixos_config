{pkgs, ...}: {
  services.xserver.displayManager.startx.enable = true;
  services.xserver.windowManager.dwm.enable = true;
  services.picom.enable = true;
  nixpkgs.overlays = [
    (final: prev: {
      dwm = prev.dwm.overrideAttrs (old: {
        src = ./dwm;
        buildInputs = old.buildInputs ++ [pkgs.imlib2];
      });
      dwmblocks = prev.dwmblocks.overrideAttrs (old: {
        src = ./dwmblocks;
        buildInputs = old.buildInputs ++ [
          pkgs.imlib2 
          pkgs.xorg.libX11.dev 
          pkgs.xorg.libXext
          pkgs.xorg.libXft
          pkgs.xorg.libXinerama
          pkgs.harfbuzzFull
        ];
      });
    })
  ];
  environment.systemPackages = with pkgs; [
    imlib2Full
    xorg.xsetroot
    slstatus
    gnumake
    dwmblocks
    dmenu
    slock
    xorg.libX11.dev
    xorg.libXft
    xorg.libXinerama
    xorg.xinit
    xorg.xrdb
    xorg.xset
    xorg.xcbutil
    xorg.libX11.dev
    xorg.xbacklight
    xorg.xrandr
    sx
    st
    light
    libgcc
    xautolock
    dash
    autorandr
    harfbuzzFull
  ];
}
