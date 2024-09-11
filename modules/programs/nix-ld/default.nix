{ pkgs, ... }: {
  programs.nix-ld = {
    enable = true;
    libraries = with pkgs; [
      stdenv.cc.cc
      # alsa-lib
      # at-spi2-atk
      # at-spi2-core
      # atk
      # cairo
      # cups
      # curl
      # dbus
      # expat
      # fontconfig
      # freetype
      # fuse3
      # gdk-pixbuf
      glib
      # gtk3
      # icu
      libGL
      # libappindicator-gtk3
      # libdrm
      # libglvnd
      # libnotify
      # libpulseaudio
      # libunwind
      # libusb1
      # libuuid
      # libxkbcommon
      # libxml2
      # mesa
      # nspr
      nss
      openssl
      # pango
      # pipewire
      # systemd
      # vulkan-loader
      # xorg.libX11
      # xorg.libXScrnSaver
      # xorg.libXcomposite
      # xorg.libXcursor
      # xorg.libXdamage
      # xorg.libXext
      # xorg.libXfixes
      # xorg.libXi
      # xorg.libXrandr
      # xorg.libXrender
      # xorg.libXtst
      # xorg.libxcb
      # xorg.libxkbfile
      # xorg.libxshmfence
      zlib
    ];
  };
  # environment.sessionVariables.LD_LIBRARY_PATH = [
  #     "/run/current-system/sw/share/nix-ld/lib:$NIX_LD_LIBRARY_PATH"
  #   ];
}
