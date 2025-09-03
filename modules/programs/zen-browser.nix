{ lib
, stdenv
, pkgs
,
}:
stdenv.mkDerivation rec {
  pname = "zen-browser";
  version = "1.0.0-a.26";

  src = builtins.fetchTarball {
    url = "https://github.com/zen-browser/desktop/releases/download/${version}/zen.linux-specific.tar.bz2";
    sha256 = "sha256:1z81dg3xgfpkyj501gflx8lw7d8124iqwm27zqfja2b47zf4ai2x";
  };

  nativeBuildInputs = [ pkgs.makeWrapper ];

  runtimeLibs = with pkgs;
    [
      libGL
      stdenv.cc.cc
      fontconfig
      libxkbcommon
      zlib
      freetype
      gtk3
      libxml2
      dbus
      xcb-util-cursor
      alsa-lib
      pango
      atk
      cairo
      gdk-pixbuf
      glib
    ]
    ++ (with pkgs.xorg; [
      libxcb
      libX11
      libXcursor
      libXrandr
      libXi
      libXext
      libXcomposite
      libXdamage
      libXfixes
    ]);

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin
    cp -r * $out/bin/
    runHook postInstall
  '';

  postFixup = ''
    chmod 755 $out/bin/*
          patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" $out/bin/zen
          wrapProgram $out/bin/zen --set LD_LIBRARY_PATH "${pkgs.lib.makeLibraryPath runtimeLibs}"
          patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" $out/bin/zen-bin
          wrapProgram $out/bin/zen-bin --set LD_LIBRARY_PATH "${pkgs.lib.makeLibraryPath runtimeLibs}"
          patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" $out/bin/glxtest
          wrapProgram $out/bin/glxtest --set LD_LIBRARY_PATH "${pkgs.lib.makeLibraryPath runtimeLibs}"
          patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" $out/bin/updater
          wrapProgram $out/bin/updater --set LD_LIBRARY_PATH "${pkgs.lib.makeLibraryPath runtimeLibs}"
          patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" $out/bin/vaapitest
          wrapProgram $out/bin/vaapitest --set LD_LIBRARY_PATH "${pkgs.lib.makeLibraryPath runtimeLibs}"
  '';

  meta = with lib; {
    description = "Zen Browser";
    homepage = "https://github.com/zen-browser/desktop";
    license = licenses.unfree;
    platforms = [ "x86_64-linux" ];
  };
}
