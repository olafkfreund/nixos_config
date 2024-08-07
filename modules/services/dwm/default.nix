{pkgs, ...}: {
  # services.xserver.displayManager.startx.enable = true;
  services.xserver.windowManager.dwm.enable = true;
  nixpkgs.overlays = [
    (final: prev: {
      dwm = prev.dwm.overrideAttrs (old: {
        src = ./dwm-6.5;
        buildInputs = old.buildInputs ++ [pkgs.imlib2];
      });
      dmenu = prev.dmenu.overrideAttrs (old: {
        src = ./dmenu-5.3;
        buildInputs = old.buildInputs ++ [
          pkgs.imlib2 
          pkgs.xorg.libX11.dev 
          pkgs.xorg.libXext
          pkgs.xorg.libXft
          pkgs.xorg.libXinerama
          pkgs.harfbuzzFull
        ];

      });
      slock = prev.slock.overrideAttrs (old: {
        src = ./slock-1.5;
        buildInputs = old.buildInputs ++ [
          pkgs.imlib2 
          pkgs.xorg.libX11.dev 
          pkgs.xorg.libXext
          pkgs.xorg.libXft
          pkgs.xorg.libXinerama
          pkgs.harfbuzzFull
        ];
      });
      st = prev.st.overrideAttrs (old: {
        src = ./st-0.9.2;
        buildInputs = old.buildInputs ++ [
          pkgs.imlib2 
          pkgs.xorg.libX11.dev 
          pkgs.xorg.libXext
          pkgs.xorg.libXft
          pkgs.xorg.libXinerama
          pkgs.harfbuzzFull
        ];
      });
      slstatus = prev.slstatus.overrideAttrs (old: {
        src = ./slstatus-1.0;
        buildInputs = old.buildInputs ++ [
          pkgs.imlib2 
          pkgs.xorg.libX11.dev 
          pkgs.xorg.libXext
          pkgs.xorg.libXft
          pkgs.xorg.libXinerama
          pkgs.harfbuzzFull
        ];
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

    # services.autorandr.enable = true;
    #
    # programs.autorandr = {
    #   enable = true;
    #
    #   profiles = {
    #     "non-nix" = {
    #       fingerprint = {
    #         DP-2 = "EDID here";
    #         HDMI-A-1 = "EDID here";
    #       };
    #       config = {
    #         DP-2 = {
    #           enable = true;
    #           crtc = 1;
    #           position = "0x0";
    #           mode = "2560x1600";
    #           rate = "165.00";
    #         };
    #         HDMI-A-1 = {
    #           enable = true;
    #           crtc = 0;
    #           position = "2560x0";
    #           primary = true;
    #           rate = "74.97";
    #           mode = "2560x1440";
    #         };
    #       };
    #     };
    #   };
    # };

  environment.systemPackages = with pkgs; [
    (import ./statusbar/sb-clock.nix { inherit pkgs; })
    (import ./statusbar/sb-battery.nix { inherit pkgs; })
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
    picom
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
