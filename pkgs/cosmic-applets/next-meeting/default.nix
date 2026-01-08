{ lib
, stdenv
, rustPlatform
, fetchFromGitHub
, pkg-config
, just
, libxkbcommon
, wayland
, evolution-data-server
, glib
}:

rustPlatform.buildRustPackage rec {
  pname = "cosmic-next-meeting";
  version = "0.9.0-unstable-2026-01-08";

  src = fetchFromGitHub {
    owner = "dangrover";
    repo = "next-meeting-for-cosmic";
    rev = "7a4213e808c1d440a105898cea807a38cd6a8c0f"; # Latest commit as of 2026-01-08
    hash = "sha256-1IQ7/tWj5jRDXMHLAbsjDgRcCthPlp61/LDdi8PcBZw=";
  };

  cargoHash = "sha256-idB3kVzc2BlsjWpHfE9urRcR+QYO6gwiqhWC7uZc/AA=";

  nativeBuildInputs = [
    pkg-config
    just
  ];

  buildInputs = [
    libxkbcommon
    wayland
    evolution-data-server
    glib
  ];

  strictDeps = true;

  dontUseJustBuild = true;
  dontUseJustCheck = true;
  dontUseJustInstall = true;

  installPhase = ''
    runHook preInstall

    install -Dm0755 target/${stdenv.hostPlatform.rust.cargoShortTarget}/release/${pname} $out/bin/${pname}
    install -Dm0644 resources/app.desktop $out/share/applications/com.dangrover.next-meeting-app.desktop
    install -Dm0644 resources/app.metainfo.xml $out/share/metainfo/com.dangrover.next-meeting-app.metainfo.xml
    install -Dm0644 resources/icon.svg $out/share/icons/hicolor/scalable/apps/com.dangrover.next-meeting-app.svg
    install -Dm0644 resources/icon-symbolic.svg $out/share/icons/hicolor/symbolic/apps/com.dangrover.next-meeting-app-symbolic.svg

    runHook postInstall
  '';

  meta = with lib; {
    description = "COSMIC panel applet showing next meeting with one-click join for video calls";
    longDescription = ''
      A COSMIC desktop panel applet that displays upcoming calendar events with
      one-click join buttons for video calls (Google Meet, Zoom, Teams, Webex).

      Features:
      - Shows meeting title, time, and location in the panel
      - Provides one-click join for video calls
      - Integrates with Evolution Data Server (EDS) calendars
      - Supports flexible formatting (absolute/relative time, location info, calendar colors)
      - Smart filtering by calendar, all-day events, or acceptance status

      Note: Requires Evolution Data Server for calendar access. Configure calendars
      via GNOME Online Accounts or Evolution directly.
    '';
    homepage = "https://github.com/dangrover/next-meeting-for-cosmic";
    license = licenses.gpl3Only;
    maintainers = with maintainers; [ ];
    platforms = platforms.linux;
    mainProgram = "cosmic-next-meeting";
  };
}
