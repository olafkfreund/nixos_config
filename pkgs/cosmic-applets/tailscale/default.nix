{ lib
, stdenv
, rustPlatform
, fetchFromGitHub
, pkg-config
, just
, libxkbcommon
, wayland
}:

rustPlatform.buildRustPackage rec {
  pname = "gui-scale-applet";
  version = "3.0.0-unstable-2025-11-29";

  src = fetchFromGitHub {
    owner = "cosmic-utils";
    repo = "gui-scale-applet";
    rev = "9528f588d7a010149071136ea3f9948771f7d0cf"; # Latest commit as of 2025-11-29
    hash = "sha256-/oTU+FF10YhgadIG61M8R9LQUV3kkcLczlbV9/53D7I=";
  };

  cargoHash = "sha256-G0YJifAC+/cl9l592vDGmVDsMwG6VyJLfw0abc/3PKk=";

  nativeBuildInputs = [
    pkg-config
    just
  ];

  buildInputs = [
    libxkbcommon
    wayland
  ];

  strictDeps = true;

  dontUseJustBuild = true;
  dontUseJustCheck = true;

  # The upstream justfile uses 'sudo install' which doesn't work in Nix sandbox
  # We implement our own installPhase instead
  dontUseJustInstall = true;

  installPhase = ''
    runHook preInstall

    install -Dm0755 target/${stdenv.hostPlatform.rust.cargoShortTarget}/release/${pname} $out/bin/${pname}

    # Install and patch desktop file with correct Exec path for NixOS
    install -Dm0644 data/com.bhh32.GUIScaleApplet.desktop $out/share/applications/com.bhh32.GUIScaleApplet.desktop
    substituteInPlace $out/share/applications/com.bhh32.GUIScaleApplet.desktop \
      --replace-fail "Exec=/usr/bin/gui-scale-applet" "Exec=$out/bin/${pname}"

    install -Dm0644 data/com.github.bhh32.GUIScaleApplet.metainfo.xml $out/share/metainfo/com.github.bhh32.GUIScaleApplet.metainfo.xml
    install -Dm0644 data/icons/scalable/apps/tailscale-icon.png $out/share/icons/hicolor/scalable/status/tailscale-icon.png

    runHook postInstall
  '';

  meta = with lib; {
    description = "COSMIC panel applet for Tailscale VPN management";
    longDescription = ''
      A Tailscale management applet for the COSMIC desktop environment.

      Features:
      - Visual network status indicator
      - Quick connect/disconnect actions
      - Network selection interface
      - Exit node configuration
      - Tailscale settings access

      Note: Requires Tailscale to be installed and users must have operator
      privileges. Run: sudo tailscale set --operator=$USER
    '';
    homepage = "https://github.com/cosmic-utils/gui-scale-applet";
    license = licenses.gpl3Only;
    maintainers = with maintainers; [ ];
    platforms = platforms.linux;
    mainProgram = "gui-scale-applet";
  };
}
