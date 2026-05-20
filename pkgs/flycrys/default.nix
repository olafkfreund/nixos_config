{ lib
, rustPlatform
, fetchFromGitHub
, pkg-config
, wrapGAppsHook4
, gtk4
, vte-gtk4
, webkitgtk_6_0
, libsoup_3
, glib
,
}:
# FlyCrys — GTK4/Libadwaita-native GUI for Anthropic's Claude Code CLI.
# Upstream: https://github.com/SergKam/FlyCrys
#
# Wraps the locally-installed `claude` binary. We install Claude Code via
# `programs.claude-code.enable` in home-manager, so the wrapper lands at
# ~/.nix-profile/bin/claude in the user's PATH, which is what FlyCrys
# spawns at runtime — no env-var wiring needed here.
rustPlatform.buildRustPackage rec {
  pname = "flycrys";
  version = "0.3.0";

  src = fetchFromGitHub {
    owner = "SergKam";
    repo = "FlyCrys";
    rev = "v${version}";
    hash = "sha256-MNVC2yOrJCAecvNqtRycZAJ1oX7NLo6d/587XWyBa0I=";
  };

  cargoHash = "sha256-zIHlhLWhqgx7fTPgDguOa3NoBR2VVoGvXpgrJiFtGnw=";

  nativeBuildInputs = [
    pkg-config
    wrapGAppsHook4
  ];

  buildInputs = [
    gtk4
    vte-gtk4
    webkitgtk_6_0
    libsoup_3
    glib
  ];

  # Upstream's .deb assets reference a desktop entry + icons that
  # buildRustPackage's default install doesn't pick up. Drop them into the
  # standard share/ layout so GNOME finds the launcher and icon.
  postInstall = ''
    install -Dm644 com.flycrys.app.desktop \
      $out/share/applications/com.flycrys.app.desktop
    for size in 48 128 256 512; do
      install -Dm644 "data/icons/hicolor/''${size}x''${size}/apps/flycrys.png" \
        "$out/share/icons/hicolor/''${size}x''${size}/apps/flycrys.png"
    done
    install -Dm644 data/about-logo.png $out/share/flycrys/data/about-logo.png
  '';

  meta = with lib; {
    description = "Lightning-fast, Linux-native agentic UI on top of Claude Code CLI";
    homepage = "https://github.com/SergKam/FlyCrys";
    license = licenses.mit;
    platforms = platforms.linux;
    mainProgram = "flycrys";
  };
}
